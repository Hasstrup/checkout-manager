# frozen_string_literal: true

module Checkout
  module Core
    class DiscountApplicator
      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(cart:, discounts:)
        @cart = cart
        @discounts = discounts
      end

      def call; end

      private

      attr_reader :carts, :discounts
    end
  end
end
