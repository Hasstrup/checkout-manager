# frozen_string_literal: true

module Checkout
  module Core
    class RuleParser
      def self.parse(*args)
        new(*args).parse
      end

      def initialize(source)
        @source = source
      end

      def parse; end

      private

      attr_reader :source
    end
  end
end
