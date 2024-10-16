# frozen_string_literal: true

require "yaml"
require "checkout/models/discount"
module Checkout
  module Models
    INVENTORY_KEYS = %i[items discounts source_file_path].freeze
    INVENTORY_ITEM_MODEL_KEYS = %i[name id cost].freeze

    # @!attribute [rw] name
    #   @return [String] the name of the inventory item
    # @!attribute [rw] id
    #   @return [Integer, String] a unique identifier for the inventory item
    # @!attribute [rw] cost
    #   @return [Integer, Float] how much the item costs
    InventoryItem = Struct.new(*INVENTORY_ITEM_MODEL_KEYS, keyword_init: true)

    # @!attribute [rw] items
    #   @return [Array<Checkout::Models::InventoryItem>] items contained within the current inventory
    # @!attribute [rw] discounts
    #   @return [Array<Checkout::Models::Discount>] items contained within the current inventor
    # @!attribute [rw] source_file_path
    #   @return [String] path to the file containing the item and discount definitions.
    Inventory = Struct.new(*INVENTORY_KEYS, keyword_init: true) do
      # Takes in the discount attributes, builds the discount struct and appends
      # it to it's discounts field. If the optional persist argument is passed, then
      # the source file will be updated.
      #
      # @param [Hash] discount_attributes
      # @param [Boolean] persist
      # @return [Checkout::Models::Discount]
      def add_discount(discount_attributes, persist: false)
        add_inventory_record!(
          attributes: discount_attributes,
          selectors: DISCOUNT_KEYS,
          klass: Discount,
          field: :discounts,
          persist: persist
        )
      end

      # Builds the InventoryItem struct from the passed attributes, and appends
      # it to it's items field. If the optional persist argument is passed, then
      # the source file will be updated.
      #
      # @param [Hash] item_attributes
      # @param [Boolean] persist
      # @return [Checkout::Models::Discount]
      def add_item(item_attributes, persist: false)
        add_inventory_record!(
          attributes: item_attributes,
          selectors: INVENTORY_ITEM_MODEL_KEYS,
          klass: InventoryItem,
          field: :items,
          persist: persist
        )
      end

      # Receives an item_name, checks it's store and returns the matching item.
      #
      # @param [String] item_name
      # @return [Checkout::Models::InventoryItem]
      def find_item(item_name)
        items.find { |item| item.name == item_name }
      end

      private

      # @param [Hash] attributes
      # @param [Array<Symbol>] selectors
      # @param [Checkout::Models::InventoryItem, Checkout::Models::Discount] klass
      # @param [Symbol] field
      # @param [Boolean] persist
      # @return [Checkout::Models::InventoryItem | Checkout::Models::Discount]
      def add_inventory_record!(attributes:, selectors:, klass:, field:, persist:)
        record_attributes = attributes.slice(*selectors)
        return unless record_valid_for_write?(record_attributes, selectors)

        klass.new(**attributes).tap do |inventory_record|
          send(field) << inventory_record
          persist_to_source_file!(record_attributes, field) if persist
        end
      end

      # Checks if all the keys for a inventory child class is contained in the
      # given input. Validation is simple at the moment - we only check for
      # key presence. In the future, we could
      # check for type consistency.
      #
      # @param [Hash] record_attributes
      # @param [Array<Symbol>] selectors
      # @return [Boolean]
      def record_valid_for_write?(record_attributes, selectors)
        selectors.all? do |selector_key|
          record_attributes.key?(selector_key)
        end
      end

      # Load up the inventory records contained in the source file.
      #
      # @return [Hash]
      def source
        @source ||= YAML.load_file(source_file_path)
      end

      # @param [Hash] inventory_record
      # @param [Symbol] field
      def persist_to_source_file!(inventory_record, field)
        records = source.dup
        records[field.to_s][inventory_record[:name]] = inventory_record.transform_keys(&:to_s)
        write_to_source_file!(records)
      end

      # @param [Hash] records
      def write_to_source_file!(records)
        File.open(source_file_path, "w") do |file|
          file.write(records.to_yaml)
        end
      end
    end
  end
end
