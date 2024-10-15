# frozen_string_literal: true

module Checkout
  module Models
    MODEL_KEYS = %i[name id cost].freeze
    Item = Struct.new(*MODEL_KEYS, keyword_init: true)
  end
end
