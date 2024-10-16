# frozen_string_literal: true

module Checkout
  module Core
    module Concerns
      module DiscountOperations
        def base_discount_for(entry)
          new(
            global: false,
            deductible_type: :unit,
            deductible_amount: 0,
            fixed_amount_total: nil,
            application_context: :single,
            applicable_item_count: 1,
            applicable_item_id: entry.item.id,
            usable: true,
            priority: 1,
            gt_bias: nil,
            name: :"base_discount_on_#{entry.item.name.downcase}" # e.g base_discount_on_c
          )
        end
      end
    end
  end
end
