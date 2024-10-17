# frozen_string_literal: true

module Checkout
  module Core
    module Concerns
      module StoreCalculations
        # @param [::Checkout::Models::InventoryItem] inventory item to be added
        # @return [Hash] the current entry context
        def add(item)
          store_entries[item.name] = {
            amount: (store_entries.dig(item.name, :amount) || 0) + 1,
            item: item
          }
        end

        # @param [::Checkout::Models::InventoryItem] inventory item to be removed
        # @return [Integer, nil] current count of the item
        def remove(item)
          store_entries[item.name] &&
            store_entries[item.name][:amount] -= 1
        end
      end
    end
  end
end
