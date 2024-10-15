# frozen_string_literal: true

require "yaml"
require "checkout/models/inventory"
require "checkout/models/item"
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
      # @return [String]
      def initialize(source_path = nil)
        @source_path = source_path
      end

      # reads the yam file and builds the inventory object
      # @return [Checkout::Models::Inventory]
      # @examples:
      #  ::Checkout::Core::InventoryBuilder.build
      def build
        ::Checkout::Models::Inventory.new(
          items: inventory_items,
          discounts: inventory_discounts
        )
      end

      private

      attr_reader :source_path

      def inventory_source
        @inventory_source ||=
          ::YAML.load_file(source_path || File.join(File.dirname(__FILE__), "./inventory.yml"))
      end

      def inventory_items
        @inventory_items ||= inventory_source[INVENTORY_ITEMS_KEY].map do |_, item_attributes|
          ::Checkout::Models::Item.new(**item_attributes)
        end
      end

      def inventory_discounts
        @inventory_discounts ||= inventory_source[INVENTORY_DISCOUNTS_KEY].map do |key, discount_attributes|
          ::Checkout::Models::Discount.new(**discount_attributes.merge(name: key))
        end
      end
    end
  end
end
