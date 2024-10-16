# frozen_string_literal: true

module Checkout
  module Core
    module Concerns
      module CursorOperations
        def build_for(cart_entry)
          new(entry: cart_entry,
              remainder: cart_entry.amount,
              current_cost: 0,
              applied_discounts: [])
        end
      end
    end
  end
end
