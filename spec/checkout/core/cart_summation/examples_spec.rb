# frozen_string_literal: true

require "checkout/models/cart"
require "checkout/core/cart_summator"

# Specs defined here satisfy the examples specified in the tech task.
# We're using the base rules defined in checkout/core/inventory.yml.
RSpec.describe Checkout::Core::CartSummator do
  let(:cart) { Checkout::Models::Cart.new }
  let(:result) { cart.bulk_scan(item_list).total }
  let(:cursors) { result.cursors }

  describe "#call" do
    context "for items: [A, B, C]" do
      let(:item_list) { "A, B, C" }
      let(:expected_cursor_map) do
        {
          A: { original_cost: 50, applied_discounts: [], amount: 1, actual_cost: 50 },
          B: { original_cost: 30, applied_discounts: [], amount: 1, actual_cost: 30 },
          C: { original_cost: 20, applied_discounts: [:base_discount_on_c], amount: 1, actual_cost: 20 }
        }
      end

      it "computes the total correctly" do
        aggregate_failures do
          expect(result.total).to eq(100)
        end
      end

      it "defines the discounts applied on the cursors" do
        aggregate_failures do
          expect(cursors.size).to eq(3)
          expected_cursor_map.each do |key, cursor_attributes|
            cursor = result.cursor_for(key.to_s)
            expect(cursor.current_cost).to eq(cursor_attributes[:actual_cost])
            expect(cursor.entry.amount).to eq(cursor_attributes[:amount])
            expect(cursor.entry.amount * cursor.entry.item.cost).to eq(cursor_attributes[:original_cost])
            expect(cursor.applied_discounts).to eq(cursor_attributes[:applied_discounts])
          end
        end
      end
    end

    context "for items: [B, A, B, B, A]" do
      let(:item_list) { "B, A, B, B, A" }
      let(:expected_cursor_map) do
        {
          #  Applies the fixed amount totals to each entry
          #
          A: { original_cost: 100, applied_discounts: ["batch_discount_on_a"], amount: 2, actual_cost: 90 },
          B: { original_cost: 90, applied_discounts: ["batch_discount_on_b"], amount: 3, actual_cost: 75 }
        }
      end

      it "computes the total correctly" do
        aggregate_failures do
          expect(result.total).to eq(165)
        end
      end

      it "defines the discounts applied on the cursors" do
        expect(cursors.size).to eq(2)

        aggregate_failures do
          expected_cursor_map.each do |key, cursor_attributes|
            cursor = result.cursor_for(key.to_s)
            expect(cursor.current_cost).to eq(cursor_attributes[:actual_cost])
            expect(cursor.entry.amount).to eq(cursor_attributes[:amount])
            expect(cursor.entry.amount * cursor.entry.item.cost).to eq(cursor_attributes[:original_cost])
            expect(cursor.applied_discounts).to eq(cursor_attributes[:applied_discounts])
          end
        end
      end
    end

    context "for items: [C, B, A, A, C, B, C]" do
      let(:item_list) { "C, B, A, A, C, B, C" }
      let(:expected_cursor_map) do
        {
          #  Applies the fixed amount totals to each entry as defined in the example.
          A: { original_cost: 100, applied_discounts: ["batch_discount_on_a"], amount: 2, actual_cost: 90 },
          B: { original_cost: 60, applied_discounts: [], amount: 2, actual_cost: 60 },
          C: { original_cost: 60, applied_discounts: [:base_discount_on_c], amount: 3, actual_cost: 60 }
        }
      end

      it "computes the total correctly" do
        aggregate_failures do
          expect(result.total).to eq(189)
        end
      end

      it "defines the discounts applied on the cursors" do
        expect(cursors.size).to eq(3)

        aggregate_failures do
          expect(result.global_discounts_applied).to include("group_discount_on_price_total")
          expected_cursor_map.each do |key, cursor_attributes|
            cursor = result.cursor_for(key.to_s)
            expect(cursor.current_cost).to eq(cursor_attributes[:actual_cost])
            expect(cursor.entry.amount).to eq(cursor_attributes[:amount])
            expect(cursor.entry.amount * cursor.entry.item.cost).to eq(cursor_attributes[:original_cost])
            expect(cursor.applied_discounts).to eq(cursor_attributes[:applied_discounts])
          end
        end
      end
    end
  end
end
