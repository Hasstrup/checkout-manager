# frozen_string_literal: true

module Checkout
  module Models
    DISCOUNT_KEYS = %i[global deductible_type deductible_amount fixed_amount_total applicable_context
                       applicable_item_count applicable_item_id usable].freeze
    Discount = Struct.new(*DISCOUNT_KEYS, keyword_init: true)
  end
end
