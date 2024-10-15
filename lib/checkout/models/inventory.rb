# frozen_string_literal: true

module Checkout
  module Models
    INVENTORY_KEYS = %i[items discounts].freeze
    Inventory = Struct.new(*INVENTORY_KEYS, keyword_init: true)
  end
end
