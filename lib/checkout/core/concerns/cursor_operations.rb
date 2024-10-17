# frozen_string_literal: true

module Checkout
  module Core
    module Concerns
      module CursorOperations
        # Takes a cart entry and returns a new cursor with sensible defaults.
        #
        # @param [Checkout::Cart::StoreEntry] cart_entry
        # @returns [Checkout::Core::CartSummator::Cursor]
        def build_for(cart_entry)
          new(
            entry: cart_entry,
            remainder: cart_entry.amount,
            current_cost: 0,
            applied_discounts: []
          )
        end
      end
    end
  end
end
