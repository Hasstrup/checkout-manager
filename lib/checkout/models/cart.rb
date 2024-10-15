# frozen_string_literal: true

module Checkout
  module Models
    class Cart
      def initialize
        @store = {}
      end

      def total; end
      def scan; end

      private

      attr_reader :store
    end
  end
end
