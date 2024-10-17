# frozen_string_literal: true

require "yaml"
require "checkout/models/inventory"
require "checkout/models/discount"

module Checkout
  module Core
    class InventoryBuilder
      INVENTORY_ITEMS_KEY = "items"
      INVENTORY_DISCOUNTS_KEY = "discounts"

      def self.build(source_path = nil)
        new(source_path).build
      end

      # @param [String] source_path the path to the yaml file containing the inventory
      # @return [Checkout::Core::InventoryBuilder]
      def initialize(source_path = nil)
        @source_path = source_path
      end

      # Reads the yaml file and builds the inventory object
      # from the keys defined in the source file.
      #
      # @return [Checkout::Models::Inventory]
      # @examples:
      #  ::Checkout::Core::InventoryBuilder.build
      def build
        Models::Inventory.new(
          items: inventory_items,
          discounts: inventory_discounts,
          source_file_path: inventory_source_file_path
        )
      end

      private

      attr_reader :source_path

      # @return [Hash]
      def inventory_source
        @inventory_source ||= YAML.load_file(inventory_source_file_path)
      end

      # @return [String]
      def inventory_source_file_path
        @inventory_source_file_path ||= source_path || File.join(File.dirname(__FILE__), "./inventory.yml")
      end

      # @return [Array<Checkout::Models::InventoryItem>]
      def inventory_items
        @inventory_items ||= inventory_source[INVENTORY_ITEMS_KEY].map do |_, item_attributes|
          Models::InventoryItem.new(**item_attributes)
        end
      end

      # @return [Array<Checkout::Models::Discount>]
      def inventory_discounts
        @inventory_discounts ||= inventory_source[INVENTORY_DISCOUNTS_KEY].map do |key, discount_attributes|
          Models::Discount.new(**discount_attributes.merge(name: key))
        end
      end
    end
  end
end
