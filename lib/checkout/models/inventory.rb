# frozen_string_literal: true

module Checkout
  module Models
    INVENTORY_KEYS = %i[items discounts].freeze
    class Inventory < Struct.new(*INVENTORY_KEYS, keyword_init: true)
      def add_discount; end

      def add_item; end
    end
  end
end
