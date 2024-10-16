# frozen_string_literal: true

require "checkout/core/concerns/discount_operations"
module Checkout
  module Models
    DISCOUNT_KEYS = %i[name global deductible_type deductible_amount fixed_amount_total application_context
                       applicable_item_count applicable_item_id usable priority gt_bias].freeze
    Discount = Struct.new(*DISCOUNT_KEYS, keyword_init: true) do
      extend Core::Concerns::DiscountOperations

      def batch?
        !global? && application_context.to_sym == :batch
      end

      def single?
        !global? && application_context.to_sym == :single
      end

      def percentage_based?
        deductible_type.to_sym == :percentage
      end

      def unit_based?
        deductible_type.to_sym == :unit
      end

      def global?
        global
      end

      def usable?
        usable
      end

      def valid?
        usable? && valid_for_calc?
      end

      def valid_for_calc?
        batch? && applicable_item_count > 1 ||
          single? && applicable_item_count == 1 ||
          global? && deductible_amount.positive?
      end
    end
  end
end
