# frozen_string_literal: true

require "checkout/core/inventory_builder"
require "checkout/core/cart_summator"
require "checkout/core/store_calculations"
require "forwardable"

module Checkout
  module Models
    class Cart
      extend Forwardable

      StoreEntry = Struct.new(:item, :amount, keyword_init: true)
      Store = Struct.new(:store_entries, :grand_total, :net_total, keyword_init: true) do
        include Checkout::Core::StoreCalculations
      end

      def initialize
        @store = Store.new(store_entries: {})
      end

      def total
        Checkout::Core::CartSummator.call(cart: self, discounts: inventory.discounts)
      end

      def scan(item_name)
        inventory_item = inventory.find_item(item_name)
        store.add(inventory_item) if inventory_item
      end

      def bulk_scan(item_names)
        item_names.split(",").each(&method(:scan))
      end

      # delegate store_entries to store
      def_delegators :@store, *%i[store_entries]

      private

      attr_reader :store

      # remember to take in
      def inventory
        @inventory ||= ::Checkout::Core::InventoryBuilder.build
      end
    end
  end
end
