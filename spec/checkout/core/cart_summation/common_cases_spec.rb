# frozen_string_literal: true

require "checkout/models/cart"
require "checkout/models/discount"
require "checkout/core/cart_summator"

RSpec.describe Checkout::Core::CartSummator do
  let(:fixture_path) { File.join(File.dirname(__FILE__), "../../../fixtures/inventory.yml") }
  let(:cart) { Checkout::Models::Cart.new(fixture_path) }
  let(:base_discount_attributes) { Checkout::Models::Discount.base_discount_attributes }
  let(:discountable_items) { cart.items.first(2) }

  before do
    # Clear any existing discounts from the inventory
    cart.inventory.discounts = []
    applicable_discounts.each { |attributes| cart.add_discount(attributes) }
  end

  describe "cart summation with discounts" do
    let(:result) { cart.bulk_scan(cart_item_names).total }
    let(:batch_count) { rand(2..5) } # Batch quantity must be > 1
    let(:multiplier) { rand(1..4) }
    let(:overage) { rand(1..3) }
    let(:target_item) { discountable_items.first }

    let(:cart_item_names) do
      # Randomly generate scanned item names, e.g., "A, A, A, B, B, A"
      # target_item is always the first item in the cart
      target_item_entries = Array.new(batch_count * multiplier + overage) { target_item.name }.join(", ")
      overage_entries = Array.new(overage) { discountable_items.last.name }.join(", ")
      "#{target_item_entries}, #{overage_entries}"
    end

    let(:applicable_discounts) do
      discount_attributes_list.map do |attrs|
        base_discount_attributes.merge(attrs.merge(applicable_item_id: target_item.id))
      end
    end

    context "when applying batch discounts" do
      context "with a fixed amount total" do
        let(:fixed_amount_total) { 80 } # pay $80 for any batch of :batch_count

        let(:discount_attributes_list) do
          [
            {
              application_context: :batch,
              fixed_amount_total: fixed_amount_total,
              applicable_item_count: batch_count,
              name: :applicable_batch_discount
            },
            { application_context: :single, deductible_amount: 1 }
          ]
        end

        let(:discount_with_fixed_total) do
          cart.inventory.discounts.find do |discount|
            discount.application_context.to_sym == :batch &&
              discount.fixed_amount_total
          end
        end

        let(:item_with_fixed_total) do
          discountable_items.find { |item| item.id == discount_with_fixed_total.applicable_item_id }
        end

        it "applies the fixed total amount for each batch if present" do
          cursor = result.cursor_for(item_with_fixed_total.name)

          aggregate_failures "validating fixed total amount" do
            expect(cursor.current_cost).to be >= (fixed_amount_total * cursor.entry.amount / batch_count)
            expect(cursor.applied_discounts.count).to eq(cursor.entry.amount / batch_count)
            expect(cursor.applied_discounts).to include(:applicable_batch_discount)
          end
        end
      end

      context "with percentage-based deductions" do
        let(:deductible_amount) { 10 } # take 10% off for any batch of :batch_count
        let(:discount_attributes_list) do
          [
            {
              application_context: :batch,
              deductible_type: :percentage,
              deductible_amount: deductible_amount,
              applicable_item_count: batch_count,
              name: :percentage_based_batch_discount
            },
            { application_context: :single, deductible_amount: 1 }
          ]
        end
        let(:discount_with_percentage_deductions) do
          cart.inventory.discounts.find do |discount|
            discount.application_context.to_sym == :batch &&
              discount.deductible_type == :percentage
          end
        end
        let(:item_with_discount_applied) do
          discountable_items.find { |item| item.id == discount_with_percentage_deductions.applicable_item_id }
        end

        it "applies percentage-based deductions" do
          cursor = result.cursor_for(item_with_discount_applied.name)
          unit_cost_after_discount =
            cursor.entry.item.cost.to_f - (deductible_amount.to_f / 100 * cursor.entry.item.cost)

          aggregate_failures "validating percentage based deductions" do
            expect(cursor.applied_discounts.count).to eq(cursor.entry.amount / batch_count)
            expect(cursor.applied_discounts).to include(:percentage_based_batch_discount)
          end
        end
      end

      context "with unit-based deductible amount" do
        let(:deductible_amount) { 15 } # take exactly $15 from any batch of :batch_count
        let(:discount_attributes_list) do
          [
            {
              application_context: :batch,
              deductible_type: :unit,
              deductible_amount: deductible_amount,
              applicable_item_count: batch_count,
              name: :unit_based_batch_discount
            },
            { application_context: :single, deductible_amount: 1 }
          ]
        end
        let(:discount_with_unit_deductions) do
          cart.inventory.discounts.find do |discount|
            discount.application_context.to_sym == :batch &&
              discount.deductible_type == :unit
          end
        end
        let(:item_with_discount_applied) do
          discountable_items.find { |item| item.id == discount_with_unit_deductions.applicable_item_id }
        end

        it "applies unit-based deductions" do
          cursor = result.cursor_for(item_with_discount_applied.name)
          unit_cost_after_discount = cursor.entry.item.cost - deductible_amount

          aggregate_failures "validating unit based deductions" do
            expect(cursor.current_cost).to be >= (unit_cost_after_discount * cursor.entry.amount / batch_count)
            expect(cursor.applied_discounts.count).to eq(cursor.entry.amount / batch_count)
            expect(cursor.applied_discounts).to include(:unit_based_batch_discount)
          end
        end
      end
    end

    context "when applying single discounts" do
      let(:batch_count) { 1 } # batch_count is always 1 for single discounts

      context "with percentage-based deductions" do
        let(:deductible_amount) { 10 } # take 10% off from each item in cart
        let(:discount_attributes_list) do
          [
            {
              application_context: :single,
              deductible_type: :percentage,
              deductible_amount: deductible_amount,
              applicable_item_count: batch_count,
              name: :percentage_based_single_discount
            }
          ]
        end
        let(:discount_with_percentage_deductions) do
          cart.inventory.discounts.find do |discount|
            discount.application_context.to_sym == :single &&
              discount.deductible_type == :percentage
          end
        end
        let(:item_with_discount_applied) do
          discountable_items.find { |item| item.id == discount_with_percentage_deductions.applicable_item_id }
        end

        it "applies percentage-based deductions" do
          cursor = result.cursor_for(item_with_discount_applied.name)
          unit_cost_after_discount =
            cursor.entry.item.cost.to_f - (deductible_amount.to_f / 100 * cursor.entry.item.cost)

          aggregate_failures "validating percentage based deductions" do
            expect(cursor.current_cost).to be >= unit_cost_after_discount.to_f * cursor.entry.amount
            expect(cursor.applied_discounts).to include(:percentage_based_single_discount)
          end
        end
      end

      context "with unit-based deductible amount" do
        let(:deductible_amount) { 15 } # take exactly $15 from each item in cart
        let(:discount_attributes_list) do
          [
            {
              application_context: :single,
              deductible_type: :unit,
              deductible_amount: deductible_amount,
              applicable_item_count: batch_count,
              name: :unit_based_single_discount
            }
          ]
        end
        let(:discount_with_unit_deductions) do
          cart.inventory.discounts.find do |discount|
            discount.application_context.to_sym == :single &&
              discount.deductible_type == :unit
          end
        end
        let(:item_with_discount_applied) do
          discountable_items.find { |item| item.id == discount_with_unit_deductions.applicable_item_id }
        end

        it "applies unit-based deductions" do
          cursor = result.cursor_for(item_with_discount_applied.name)
          unit_cost_after_discount = cursor.entry.item.cost - deductible_amount

          aggregate_failures "validating unit based deductions" do
            expect(cursor.current_cost).to be >= (unit_cost_after_discount * cursor.entry.amount)
            expect(cursor.applied_discounts).to include(:unit_based_single_discount)
          end
        end
      end
    end

    context "when applying global discounts" do
      let(:result) { cart.bulk_scan(cart_item_names).total }
      let(:actual_total_cost) { result.cursors.sum(&:current_cost) }

      context "when there is a gt bias" do # only apply discount if total cart price > gt_bias
        let(:discount_attributes_list) do
          [
            {
              global: true,
              gt_bias: 150,
              deductible_type: :percentage,
              deductible_amount: 10,
              name: :global_discount_on_price_total
            }
          ]
        end

        let(:discount) do
          cart.inventory.discounts.find do |discount|
            discount.global? && discount.gt_bias
          end
        end

        context "when the cart price is greater than or equal to the gt_bias" do
          let(:cart_item_names) { "A, A, A, A, B" } # this totals $230 per fixtures/inventory.yaml

          it "applies the discount on the total cart price" do
            aggregate_failures do
              expect(result.global_discounts_applied).to include(:global_discount_on_price_total)
              expect(result.total).to eq(
                actual_total_cost - (discount.deductible_amount.to_f / 100 * actual_total_cost)
              )
            end
          end
        end

        context "when the cart price is less than the gt_bias" do
          let(:cart_item_names) { "A, A," }

          it "does NOT apply the discount on the total price" do
            aggregate_failures do
              expect(result.global_discounts_applied).to be_empty
              expect(result.total).to eq(actual_total_cost)
            end
          end
        end
      end

      context "when there is no gt_bias" do
        let(:discount_attributes_list) do
          [
            {
              global: true,
              gt_bias: nil,
              deductible_type: :percentage,
              deductible_amount: 10,
              name: :global_discount_on_price_total
            }
          ]
        end
        let(:cart_item_names) { "A, A, A, A, B" } # this totals $230 per fixtures/inventory.yaml
        let(:discount) do
          cart.inventory.discounts.find do |discount|
            discount.global? && !discount.gt_bias
          end
        end

        it "applies the discount on the total cart price" do
          aggregate_failures do
            expect(result.global_discounts_applied).to include(:global_discount_on_price_total)
            expect(result.total).to eq(
              actual_total_cost - (discount.deductible_amount.to_f / 100 * actual_total_cost)
            )
          end
        end
      end
    end
  end
end
