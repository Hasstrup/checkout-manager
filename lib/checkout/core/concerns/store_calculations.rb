# frozen_string_literal: true

module Checkout
  module Core
    module Concerns
      module StoreCalculations
        def add(item)
          store_entries[item.name] = {
            amount: (store_entries.dig(item.name, :amount) || 0) + 1,
            item: item
          }
        end

        def remove(item)
          store_entries[item.name] &&
            store_entries[item.name][:amount] -= 1
        end

        def find(item_name)
          store_entries[item_name]
        end
      end
    end
  end
end
