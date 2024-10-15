# frozen_string_literal: true

module Checkout
  module Models
    ITEM_MODEL_KEYS = %i[name id cost].freeze
    Item = Struct.new(*ITEM_MODEL_KEYS, keyword_init: true)
  end
end
