# frozen_string_literal: true

require "checkout/models/cart"
require "checkout/core/cart_summator"

RSpec.describe Checkout::Models::Cart do
  let(:fixture_path) { File.join(File.dirname(__FILE__), "../../fixtures/inventory.yml") }
  let(:cart) { described_class.new(fixture_path) }

  describe "#scan" do
    let(:item_name) { "A" }
    let(:entries) { cart.scan(item_name).entries }
    let(:target_entry) { entries.find { |entry| entry.item.name == item_name } }

    context "when the item name is present in the inventory" do
      it "takes an item name and adds it to it's store" do
        aggregate_failures do
          expect(entries.size).to eq(1)
          expect(entries.first.item.name).to eq("A")
          expect(entries.first.item.cost).to eq(50)
          expect(entries.first.amount).to eq(1)
        end
      end
    end

    context "when the item name is not present in the inventory" do
      let(:item_name) { "D" }

      it "does not add to the list of entries" do
        expect(target_entry).to be_nil
      end
    end
  end

  describe "#bulk_scan" do
    let(:item_names) { "A, A, A, A, B, B" }
    let(:entries) { cart.bulk_scan(item_names).entries }

    context "when sent a correctly formatted list of input names" do
      it "parses the list of items and scans them into it's store" do
        a_entry = entries.find { |entry| entry.item.name == "A" }
        b_entry = entries.find { |entry| entry.item.name == "B" }
        aggregate_failures do
          expect(entries.size).to eq(2)
          expect(a_entry.amount).to eq(4)
          expect(b_entry.amount).to eq(2)
        end
      end
    end

    context "when sent an incorrect list of input names" do
      let(:item_names) { "A,B,C,D" }

      it "does nothing" do # should this throw an exception instead?
        expect(cart.bulk_scan(item_names).entries.size).to eq(0)
      end
    end
  end

  describe "#total" do
    let(:item_names) { "A, A, A, A, B, B" }
    let(:result) { cart.bulk_scan(item_names).total }

    it "computes the total amount of the contained entries" do
      aggregate_failures do
        expect(result).to be_a(Checkout::Core::CartSummator::SummationResult)
      end
    end
  end
end
