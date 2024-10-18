# frozen_string_literal: true

require "checkout/core/inventory_builder"
require "checkout/models/inventory"
require "checkout/models/discount"

RSpec.describe Checkout::Core::InventoryBuilder do
  let(:fixture_path) { File.join(File.dirname(__FILE__), "../../fixtures/inventory.yml") }
  let(:inventory) { builder.build }

  describe "#build" do
    context "when passed a source file path" do
      let(:builder) { described_class.new(fixture_path) }

      it "builds the inventory items correctly from the given source" do
        aggregate_failures do
          expect(inventory.items.count).to eq(2)
          expect(inventory.items.sample).to be_a(::Checkout::Models::InventoryItem)
          expect(inventory.items.first.cost).to eq(50)
        end
      end

      it "builds the discounts (and their properties) correctly from the given source" do
        aggregate_failures do
          expect(inventory.discounts.count).to eq(2)
          expect(inventory.discounts.sample).to be_a(::Checkout::Models::Discount)
          expect(inventory.discounts.first.name).to eq("group_discount_on_price_total")
        end
      end
    end

    context "when a source file path is NOT provided" do
      let(:builder) { described_class.new }

      it "builds the inventory items from the local inventory source" do # present in /core/inventory.yml
        aggregate_failures do
          expect(inventory.items.count).to eq(3)
          expect(inventory.items.sample).to be_a(::Checkout::Models::InventoryItem)
          expect(inventory.items.first.cost).to eq(50)
        end
      end

      it "builds the discounts (and their properties) correctly from the local inventory source" do
        aggregate_failures do
          expect(inventory.discounts.count).to eq(4)
          expect(inventory.discounts.sample).to be_a(::Checkout::Models::Discount)
          expect(inventory.discounts.first.name).to eq("batch_discount_on_a")
        end
      end
    end
  end
end
