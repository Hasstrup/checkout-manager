# frozen_string_literal: true

require "checkout/core/concerns/cursor_operations"
require "checkout/models/discount"
module Checkout
  module Core
    class CartSummator
      CURSOR_KEYS = %i[entry current_cost remainder applied_discounts].freeze
      SUMMATION_RESULT_KEYS = %i[total cursors global_discounts_applied].freeze

      # @!attribute [rw] entry
      #   @return [Checkout::Cart::StoreEntry] the store entry currently being processed
      # @!attribute [rw] current_cost
      #   @return [Integer, Float] the current cost of the item within the context of discount application.
      # @!attribute [rw] remainder
      #   @return [Integer] how many items left after discount application
      # @!attribute [rw] applied_discounts
      #  @return [Array<String>] names of discounts that were applied on the current entry
      Cursor = Struct.new(*CURSOR_KEYS, keyword_init: true) do
        extend Core::Concerns::CursorOperations
      end

      # @!attribute [rw] total
      #   @return [Integer, Float]
      # @!attribute [rw] cursors
      #   @return [Array<Checkout::Core::CartSummator::Cursors>] list of price cursors  used during summation
      # @!attribute [rw] global_applied_discounts
      #  @return [Array<String>] names of discounts that were applied on the total price.
      SummationResult = Struct.new(*SUMMATION_RESULT_KEYS, keyword_init: true) do
        # @param [String] item_name
        # @return [Checkout::Core::CartSummator::Cursor]
        def cursor_for(item_name)
          cursors.find do |cursor|
            cursor.entry.item.name == item_name
          end
        end
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      # @param [Checkout::Models::Cart] cart the current cart in context
      # @param [Checkout::Models::Discount] discounts a list of applicable discounts
      # @return [Checkout::Core::CartSummator]
      def initialize(cart:, discounts:)
        @cart = cart
        @discounts = discounts
        @applied_global_discounts = []
      end

      # To calculate the total, we get all the entries in the cart, each entry has an amount field
      # along with the inventory item - each entry looks like this -> { item: #inventory_item, amount: #amount }. We loop
      # through these entries, check the inventory for the discounts defined for each one,
      # and send this combination (entry + discounts) for price calculation.
      # When calulcating the price for each entry, we separate the discounts into batch and single discounts.
      # We recursively go through the batch discounts (if any), applying their deductible to
      # the price and reducing the cursor's remainder in the process. After all the batch discounts are applied,
      # we apply the single discounts to the remaining items - until the remainder reaches zero.
      # We then sum the final prices of each cursor - and then apply global discounts on the total, while respecting
      # any price biases that are defined in the discount.
      #
      # @return [Checkout::Core::CartSummator::SummationResult]
      def call
        SummationResult.new(
          total: apply_global_discounts(applied_cart_cursors.sum(&:current_cost)),
          cursors: applied_cart_cursors,
          global_discounts_applied: applied_global_discounts
        )
      end

      private

      attr_reader :cart, :discounts, :applied_global_discounts

      # @return [Array<Checkout::Core::CartSummator::Cursor>]
      def applied_cart_cursors
        @applied_cart_cursors ||= cart.entries.map do |cart_entry|
          build_entry_cursor_with_discount(cart_entry)
        end
      end

      # Discounts vary in how their validities are determined,
      # but at this point we delegate that to the discount class to compute that for us.
      #
      # @return [Array<Checkout::Models::Discount>]
      def usable_discounts
        @usable_discounts ||= discounts.select(&:valid?)
      end

      # Takes a cart entry, fetches and partitions the discounts and applies them on the
      # price of the entry item.
      #
      # @param [Checkout::Models::Cart::StoreEntry] cart_entry
      # @return [Checkout::Core::CartSummator::Cursor]
      def build_entry_cursor_with_discount(cart_entry)
        batch_discounts, single_discounts = applicable_discounts_for(cart_entry)
        cursor = apply_batch_discounts(initial_cursor_for(cart_entry), batch_discounts)
        apply_single_discounts!(cursor, single_discounts)
      end

      # @return [Checkout::Core::CartSummator::Cursor]
      def initial_cursor_for(cart_entry)
        Cursor.build_for(cart_entry)
      end

      # @param [Checkout::Core::CartSummator::Cursor] initial_cursor
      # @param [Array<Checkout::Models::Discount>] discounts
      # @return [Checkout::Core::CartSummator::Cursor]
      def apply_batch_discounts(initial_cursor, discounts)
        discounts.reduce(initial_cursor) do |cursor, discount|
          apply_batch_discount!(cursor, discount)
        end
      end

      # While applying batch discounts, we check for any fixed_amount defined for the batch
      # per the discount - if there's one defined, that takes precedence over the actual cost of items.
      #
      # @param [Checkout::Core::CartSummator::Cursor] cursor
      # @param [Array<Checkout::Models::Discount>] discounts
      # @return [Checkout::Core::CartSummator::Cursor]
      def apply_batch_discount!(cursor, discount)
        return cursor unless apply_batch_discount?(cursor, discount)

        original_cost = cursor.entry.item.cost
        cursor.current_cost += discount.fixed_amount_total || infer_additional_entry_cost(original_cost, discount)
        cursor.remainder -= discount.applicable_item_count
        cursor.applied_discounts << discount.name
        # if the remainder is greater than the discount's applicable_amount,
        # then take another batch and apply same discount.
        apply_batch_discount!(cursor, discount)
        cursor
      end

      # @param [Checkout::Core::CartSummator::Cursor] cursor
      # @param [Checkout::Models::Discount] discount
      # @return [Boolean]
      def apply_batch_discount?(cursor, discount)
        cursor.remainder >= discount.applicable_item_count
      end

      # @param [Integer | Float] original_cost
      # @param [Checkout::Model::Discount] discount
      # @return [Integer | Float]
      def infer_additional_entry_cost(original_cost, discount)
        original_cost - calculate_deductible(original_cost, discount) * discount.applicable_item_count
      end

      # @param [Integer | Float] original_cost
      # @param [Checkout::Models::Discount] discount
      # @return [Integer | Float]
      def calculate_deductible(original_cost, discount)
        if discount.percentage_based?
          (original_cost * (discount.deductible_amount.to_f / 100))
        else
          discount.deductible_amount
        end
      end

      # Apply all the discounts on the price of one unit and multiply that by the cursor's remainder
      # to get the final price for the items.
      #
      # @param [Checkout::Core::CartSummator::Cursor] initial_cursor
      # @param [Array<Checkout::Models::Discount>] discounts
      # @return [Checkout::Core::CartSummator::Cursor]
      def apply_single_discounts!(cursor, discounts)
        discounted_unit_price = compute_discounted_unit_price(cursor, discounts)
        cursor.current_cost += cursor.remainder * discounted_unit_price
        cursor.remainder = 0
        cursor
      end

      # @param [Checkout::Core::CartSummator::Cursor] initial_cursor
      # @param [Array<Checkout::Models::Discount>] discounts
      # @return [Integer | Float]
      def compute_discounted_unit_price(cursor, discounts)
        discounts.reduce(cursor.entry.item.cost) do |current_price, discount|
          cursor.applied_discounts << discount.name
          determine_new_price_with_discount(current_price, discount)
        end
      end

      # @param [Integer | Float] original_cost
      # @param [Checkout::Model::Discount] discount
      # @return [Integer | Float]
      def determine_new_price_with_discount(original_cost, discount)
        computed_cost = original_cost - calculate_deductible(original_cost, discount)
        computed_cost.positive? ? computed_cost : original_cost
      end

      # @param [Checkout::Models::Cart::StoreEntry] entry
      # @return [Array<Array<Checkout::Models::Discount>>]
      def applicable_discounts_for(entry)
        discounts = select_discounts_for_entry(entry)
        [
          sort_discounts(discounts.select(&:batch?)),
          sort_discounts(discounts.select(&:single?))
        ]
      end

      # @param [Checkout::Models::Cart::StoreEntry] entry
      # @return [Array<Checkout::Models::Discount>]
      def select_discounts_for_entry(entry)
        entry_discounts = usable_discounts.select { |discount| discount.applicable_item_id == entry.item.id }
        entry_discounts.any? ? entry_discounts : [Models::Discount.base_discount_for(entry.item)]
      end

      # @param [Integer | Float] original_total
      # @return [Integer | Float | nil]
      def apply_global_discounts(original_total)
        global_scope_discounts.reduce(original_total) do |current_total, discount|
          with_price_bias_applied(current_total, discount) do
            applied_global_discounts << discount.name
            determine_new_price_with_discount(current_total, discount)
          end
        end
      end

      # @param [Integer | Float] original_total
      # @param [Checkout::Model::Discount] discount
      # @return [Integer | Float | nil ]
      def with_price_bias_applied(original_total, discount)
        apply_price_bias?(original_total, discount) ? yield : original_total
      end

      # @param [Integer | Float] original_total
      # @param [Checkout::Model::Discount] discount
      # @return [Boolean]
      def apply_price_bias?(original_total, discount)
        discount.gt_bias && original_total >= discount.gt_bias
      end

      # @return [Array<Checkout::Models::Discount>]
      def global_scope_discounts
        @global_scope_discounts ||= sort_discounts(usable_discounts.select(&:global))
      end

      # @return [Array<Checkout::Models::Discount>]
      def sort_discounts(discounts)
        discounts.sort_by(&:priority)
      end
    end
  end
end
