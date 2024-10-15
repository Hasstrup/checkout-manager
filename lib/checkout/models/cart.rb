# frozen_string_literal: true

module Checkout
  module Models
    class Cart
      Store = Struct.new(:items, keyword_init: true)
      # item [::Checkout::Models::Item]
      StoreEntry = Struct.new(:item, :amount, :cost, keyword_init: true)

      def initialize
        @store = Store.new(items: [])
      end

      def total; end
      def scan; end

      # delegate items to store

      private

      attr_reader :store
    end
  end
end
