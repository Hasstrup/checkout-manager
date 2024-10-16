# frozen_string_literal: true

module Checkout
  module Core
    class CartSummator
      CURSOR_KEYS = %i[entry current_cost remainder applied_discounts].freeze
      Cursor = Struct.new(*CURSOR_KEYS, keyword_init: true)
      SummationResult = Struct.new(:total, :cursors, keyword_init: true)
      def self.call(**kwargs)
        new(**kwargs).call
      end

      #
      # @param [::Checkout::Models::Cart] cart the current cart in context
      # @param [::Checkout::Models::Discount] discounts a list of applicable discounts
      def initialize(cart:, discounts:)
        @cart = cart
        @discounts = discounts
      end

      def call
        SummationResult.new(
          cursors: applied_cart_cursors,
          total: apply_global_discounts(applied_cart_cursors.sum(&:current_cost))
        )
      end

      private

      attr_reader :cart, :discounts

      def applied_cart_cursors
        @applied_cart_cursors ||= cart.entries.map do |cart_entry|
          build_entry_cursor_with_discount(cart_entry)
        end
      end

      def usable_discounts
        @usable_discounts ||= discounts.select(&:valid?)
      end

      # find the applicable discounts apply and update the cost field
      def build_entry_cursor_with_discount(cart_entry)
        batch_discounts, single_discounts = applicable_discounts_for(cart_entry)
        cursor = apply_batch_discounts(batch_discounts, initial_cursor_for(cart_entry))
        apply_single_discounts!(single_discounts, cursor)
      end

      def initial_cursor_for(cart_entry)
        Cursor.new(
          entry: cart_entry,
          remainder: cart_entry.amount,
          current_cost: 0,
          applied_discounts: []
        )
      end

      def apply_batch_discounts(discounts, initial_cursor)
        discounts.reduce(initial_cursor) do |cursor, discount|
          apply_batch_discount!(discount, cursor)
        end
      end

      def apply_batch_discount!(discount, cursor)
        return cursor if cursor.remainder.zero?

        original_cost = cursor.entry.item.cost
        cursor.current_cost += discount.fixed_amount_total || infer_additional_entry_cost(original_cost, discount)
        cursor.remainder -= discount.applicable_item_count
        cursor.applied_discounts << discount.name # store applied discounts for introspection purposes
        # if what we have left is greater than the discount's item amount, take another batch and apply same discount
        apply_batch_discount!(discount, cursor) if reapply_discount?(cursor, discount)
        cursor
      end

      def reapply_discount?(cursor, discount)
        cursor.remainder >= discount.applicable_item_count
      end

      def infer_additional_entry_cost(original_cost, discount)
        original_cost - calculate_deductible(discount, original_cost) * discount.applicable_item_count
      end

      def calculate_deductible(discount, original_cost)
        if discount.percentage_based?
          (original_cost * (discount.deductible_amount / 100))
        else
          discount.deductible_amount
        end
      end

      def apply_single_discounts!(discounts, cursor)
        discounted_unit_price = compute_discounted_unit_price(cursor, discounts)
        cursor.current_cost += cursor.remainder * discounted_unit_price
        cursor.remainder = 0
        cursor
      end

      def compute_discounted_unit_price(cursor, discounts)
        discounts.reduce(cursor.entry.item.cost) do |current_price, discount|
          cursor.applied_discounts << discount.name
          determine_new_price_with_discount(discount, current_price)
        end
      end

      def determine_new_price_with_discount(discount, original_cost)
        computed_cost = original_cost - calculate_deductible(discount, original_cost)
        computed_cost.positive? ? computed_cost : original_cost
      end

      def applicable_discounts_for(entry)
        discounts = usable_discounts.select { |discount| discount.applicable_item_id == entry.item.id }
        [
          sort_discounts(discounts.select(&:batch?)),
          sort_discounts(discounts.select(&:single?))
        ]
      end

      def apply_global_discounts(original_total)
        global_scope_discounts.reduce(original_total) do |current_total, discount|
          determine_new_price_with_discount(discount, current_total)
        end
      end

      def global_scope_discounts
        @global_scope_discounts ||= sort_discounts(usable_discounts.select(&:global))
      end

      def sort_discounts(discounts)
        discounts.sort_by(&:priority)
      end
    end
  end
end
