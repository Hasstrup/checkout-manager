# frozen_string_literal: true

require "checkout/core/inventory_builder"
require "checkout/core/cart_summator"
require "checkout/core/concerns/store_calculations"
require "forwardable"

module Checkout
  module Models
    class Cart
      extend Forwardable

      # @!attribute [rw] item
      #   @return [Checkout::Models::InventoryItem] the contained inventory item
      # @!attribute [rw] amount
      #   @return [Integer] the amount of items ordered
      StoreEntry = Struct.new(:item, :amount, keyword_init: true)

      # @!attribute [rw] store_entries
      #   @return [Array<StoreEntry>] a list of currently ordered entries
      Store = Struct.new(:store_entries, keyword_init: true) do
        include Core::Concerns::StoreCalculations
      end

      # @param [String, nil] optional path to yml file containing rule definition
      def initialize(pricing_rules_path = nil)
        @store = Store.new(store_entries: {})
        @pricing_rules_path = pricing_rules_path
      end

      # Receives the item's name as string, finds the matching inventory item and adds to store.
      #
      # @param [String] name the name of the item
      # @return [Checkout::Models::Cart]
      def scan(item_name)
        inventory_item = inventory.find_item(item_name)
        store.add(inventory_item) if inventory_item
        self
      end

      # Receives a comma separated list of item names as string, finds the matching inventory items
      # and adds them to it's internal store.
      #
      # @param [String] name names of the items
      # @return [Checkout::Models::Cart]
      def bulk_scan(item_names)
        item_names.split(", ").each(&method(:scan))
        self
      end

      # @param [String] name the name of the item
      # @return [Array<Checkout::Models::Cart::StoreEntry>]
      def entries
        @entries ||= store.store_entries.values.map do |entry_attributes|
          StoreEntry.new(**entry_attributes)
        end
      end

      # @return [::Checkout::Core::CartSummator::SummationResult]
      def total
        Core::CartSummator.call(cart: self, discounts: inventory.discounts)
      end

      # @return [Array<Checkout::Models::Inventory>]
      def inventory
        @inventory ||= Core::InventoryBuilder.new(pricing_rules_path).build
      end

      def_delegators :@store, *%i[store_entries add remove]
      def_delegators :@inventory, *%i[add_discount add_item items discounts]

      private

      attr_reader :store, :pricing_rules_path
    end
  end
end
