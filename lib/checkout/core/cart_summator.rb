# frozen_string_literal: true

require "checkout/core/concerns/cursor_operations"
require "checkout/models/discount"
module Checkout
  module Core
    class CartSummator
      CURSOR_KEYS = %i[entry current_cost remainder applied_discounts].freeze
      SUMMATION_RESULT_KEYS = %i[total cursors global_discounts_applied].freeze

      Cursor = Struct.new(*CURSOR_KEYS, keyword_init: true) do
        extend Core::Concerns::CursorOperations
      end
      SummationResult = Struct.new(*SUMMATION_RESULT_KEYS, keyword_init: true)

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
          total: apply_global_discounts(applied_cart_cursors.sum(&:current_cost)),
          cursors: applied_cart_cursors,
          global_discounts_applied: applied_global_discounts
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
        cursor = apply_batch_discounts(initial_cursor_for(cart_entry), batch_discounts)
        apply_single_discounts!(cursor, single_discounts)
      end

      def initial_cursor_for(cart_entry)
        Cursor.build_for(cart_entry)
      end

      def apply_batch_discounts(initial_cursor, discounts)
        discounts.reduce(initial_cursor) do |cursor, discount|
          apply_batch_discount!(cursor, discount)
        end
      end

      def apply_batch_discount!(cursor, discount)
        return cursor unless apply_batch_discount?(cursor, discount)

        original_cost = cursor.entry.item.cost
        cursor.current_cost += discount.fixed_amount_total || infer_additional_entry_cost(original_cost, discount)
        cursor.remainder -= discount.applicable_item_count
        cursor.applied_discounts << discount.name # save applied discounts for introspection
        # if the remainder is greater than the discount's applicable_amount,
        # take another batch and apply same discount
        apply_batch_discount!(cursor, discount) if reapply_discount?(cursor, discount)
        cursor
      end

      def apply_batch_discount?(cursor, discount)
        cursor.remainder >= discount.applicable_item_count
      end

      def reapply_discount?(cursor, discount)
        cursor.remainder >= discount.applicable_item_count
      end

      def infer_additional_entry_cost(original_cost, discount)
        original_cost - calculate_deductible(original_cost, discount) * discount.applicable_item_count
      end

      def calculate_deductible(original_cost, discount)
        if discount.percentage_based?
          (original_cost * (discount.deductible_amount.to_f / 100))
        else
          discount.deductible_amount
        end
      end

      def apply_single_discounts!(cursor, discounts)
        discounted_unit_price = compute_discounted_unit_price(cursor, discounts)
        cursor.current_cost += cursor.remainder * discounted_unit_price
        cursor.remainder = 0
        cursor
      end

      def compute_discounted_unit_price(cursor, discounts)
        discounts.reduce(cursor.entry.item.cost) do |current_price, discount|
          cursor.applied_discounts << discount.name
          determine_new_price_with_discount(current_price, discount)
        end
      end

      def determine_new_price_with_discount(original_cost, discount)
        computed_cost = original_cost - calculate_deductible(original_cost, discount)
        computed_cost.positive? ? computed_cost : original_cost
      end

      def applicable_discounts_for(entry)
        discounts = select_discounts_for_entry(entry)
        [
          sort_discounts(discounts.select(&:batch?)),
          sort_discounts(discounts.select(&:single?))
        ]
      end

      def select_discounts_for_entry(entry)
        entry_discounts = usable_discounts.select { |discount| discount.applicable_item_id == entry.item.id }
        entry_discounts.any? ? entry_discounts : [Models::Discount.base_discount_for(entry)]
      end

      def apply_global_discounts(original_total)
        global_scope_discounts.reduce(original_total) do |current_total, discount|
          with_price_bias_applied(current_total, discount) do
            applied_global_discounts << discount.name # save discount name for tracking purposes
            determine_new_price_with_discount(current_total, discount)
          end
        end
      end

      def applied_global_discounts
        @applied_global_discounts ||= []
      end

      def with_price_bias_applied(original_total, discount)
        apply_price_bias?(original_total, discount) ? yield : original_total
      end

      def apply_price_bias?(original_total, discount)
        discount.gt_bias && original_total >= discount.gt_bias
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
