# frozen_string_literal: true

module Checkout
  module Core
    module Concerns
      module StoreCalculations
        # Takes an inventory item and adds to the store_entries key.
        #
        # @param [::Checkout::Models::InventoryItem] inventory item to be added
        # @returns [Hash] the current entry context
        def add(item)
          store_entries[item.name] = {
            amount: (store_entries.dig(item.name, :amount) || 0) + 1,
            item: item
          }
        end

        # Takes an inventory item and decreases the amount contained in the store_entries key.
        #
        # @param [::Checkout::Models::InventoryItem] inventory item to be removed
        # @returns [Integer, nil] current count of the item
        def remove(item)
          store_entries[item.name] &&
            store_entries[item.name][:amount] -= 1
        end
      end
    end
  end
end
