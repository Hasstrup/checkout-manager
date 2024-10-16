# frozen_string_literal: true

module Checkout
  module Models
    INVENTORY_KEYS = %i[items discounts].freeze
    INVENTORY_ITEM_MODEL_KEYS = %i[name id cost].freeze
    InventoryItem = Struct.new(*INVENTORY_ITEM_MODEL_KEYS, keyword_init: true)

    Inventory = Struct.new(*INVENTORY_KEYS, keyword_init: true) do
      def add_discount; end

      def add_item; end

      def find_item(item_name)
        items.find { |item| item.name == item_name }
      end
    end
  end
end
