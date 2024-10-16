# frozen_string_literal: true

require "checkout/core/concerns/discount_operations"
module Checkout
  module Models
    DISCOUNT_KEYS = %i[name global deductible_type deductible_amount fixed_amount_total application_context
                       applicable_item_count applicable_item_id usable priority gt_bias].freeze
    # @!attribute [rw] name
    #   @return [String] the name of the discount
    # @!attribute [rw] global
    #   @return [Boolean] describes whether or not the discount is applied to the total price or the item price;
    # @!attribute [rw] deductible_type
    #   @return [String] one of 'unit' or 'percentage' - the basis on which to apply the deduction.
    #   if unit - the whole deductible is subtracted from the item price else a percentage is deducted.
    # @!attribute [rw] deductible_amount
    #   @return [Integer] the amount to be deducted from the item price
    # @!attribute [rw] fixed_amount_total
    #   @return [Integer] overrides any deductible and is used as to the total for the defined item count
    #   e.g 2 entries of item A -> 90 (per the example)
    # @!attribute [rw] application_context
    #   @return [String] one of 'batch' of 'single' - batch discounts are applied to groups of items,
    #   'single' discounts are applied to each unit.
    # @!attribute [rw] applicable_item_count
    #   @return [Integer] for batch discounts, the exact number of items from which a discount is applied
    #   e.g $90 for a batch of 3 items (item A) ->
    #   {applicable_item_count: 3, fixed_amount_total: 90, application_context: :batch}
    # @!attribute [rw] applicable_item_id
    #   @return [Integer] the inventory item id for the discount applied
    # @!attribute [rw] usable
    #   @return [Boolean] used to toggle on or off the discount
    # @!attribute [rw] priority
    #   @return [Integer] determines the order in which multiple discounts for the same item are applied
    # @!attribute [rw] gt_bias
    #   @return [Integer] determines the upper price limit from which a discount is applied
    #   e.g a gt_bias of 200 will result in applying the discount from 200$ and above.
    Discount = Struct.new(*DISCOUNT_KEYS, keyword_init: true) do
      extend Core::Concerns::DiscountOperations

      # Returns whether or not a discount is applied in item batches.
      #
      # @return [Boolean]
      def batch?
        !global? && application_context&.to_sym == :batch
      end

      # Returns whether or not a discount is applied in item units.
      #
      # @return [Boolean]
      def single?
        !global? && application_context&.to_sym == :single
      end

      # @return [Boolean]
      def percentage_based?
        deductible_type&.to_sym == :percentage
      end

      # @return [Boolean]
      def unit_based?
        deductible_type&.to_sym == :unit
      end

      # @return [Boolean]
      def global?
        !!global
      end

      # @return [Boolean]
      def usable?
        !!usable
      end

      # @return [Boolean]
      def valid?
        usable? && valid_for_calc?
      end

      private

      # @return [Boolean]
      def valid_for_calc?
        batch? && applicable_item_count > 1 ||
          single? && applicable_item_count == 1 ||
          global? && deductible_amount.positive?
      end
    end
  end
end
