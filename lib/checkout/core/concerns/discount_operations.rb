# frozen_string_literal: true

module Checkout
  module Core
    module Concerns
      module DiscountOperations
        # @param [Checkout::Models::InventoryItem] entry
        # @return [Checkout::Models::Discount]
        def base_discount_for(item)
          new(
            **base_discount_attributes.merge(
              applicable_item_id: item.id,
              name: :"base_discount_on_#{item.name.downcase}"
            )
          )
        end

        # @return [Hash]
        def base_discount_attributes
          {
            global: false,
            deductible_type: :unit,
            deductible_amount: 0,
            fixed_amount_total: nil,
            application_context: :single,
            applicable_item_count: 1,
            usable: true,
            priority: 1,
            gt_bias: nil
          }
        end
      end
    end
  end
end
