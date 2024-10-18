# frozen_string_literal: true

require "checkout/models/discount"
require "checkout/core/inventory_builder"
require "checkout/models/cart"

RSpec.describe Checkout::Models::Discount do
  let(:fixture_path) { File.join(File.dirname(__FILE__), "../../fixtures/inventory.yml") }
  let(:inventory) { Checkout::Core::InventoryBuilder.new(fixture_path).build }
  let(:item) { inventory.items.first }
  let(:discount_attributes) { {} }
  let(:discount) do
    ::Checkout::Models::Discount.new(
      **Checkout::Models::Discount.base_discount_attributes
        .merge(
          name: :"base_discount_on_#{item.name.downcase}",
          applicable_item_id: item.id,
          **discount_attributes
        )
    )
  end

  shared_examples_for :a_falsifiable_discount_property do |condition, condition_attributes|
    condition_attributes.each do |attribute|
      context "when any of the #{condition} conditions are incorrect: #{attribute}" do
        let(:discount_attributes) { attribute }
        it { is_expected.to be false }
      end
    end
  end

  describe "#batch?" do
    subject { discount.batch? }

    context "when the discount is global and the application_context is batch" do
      let(:discount_attributes) { { global: false, application_context: :batch } }
      it { is_expected.to be true }
    end

    falsy_attributes = [{ global: true }, { application_context: :single }]
    it_behaves_like :a_falsifiable_discount_property, :batch?, falsy_attributes
  end

  describe "#single?" do
    subject { discount.single? }

    context "when the discount is not global and the application_context is single" do
      let(:discount_attributes) { { global: false, application_context: :single } }
      it { is_expected.to be true }
    end

    falsy_attributes = [{ global: true }, { application_context: :batch }]
    it_behaves_like :a_falsifiable_discount_property, :single?, falsy_attributes
  end

  describe "#percentage_based?" do
    subject { discount.percentage_based? }

    context "when the deductible_type is set to :percentage" do
      let(:discount_attributes) { { deductible_type: :percentage } }
      it { is_expected.to be true }
    end

    falsy_attributes = [{ deductible_type: :unit }, { deductible_type: nil }]
    it_behaves_like :a_falsifiable_discount_property, :percentage_based?, falsy_attributes
  end

  describe "#unit_based?" do
    subject { discount.unit_based? }

    context "when the deductible_type is set to :unit" do
      let(:discount_attributes) { { deductible_type: :unit } }
      it { is_expected.to be true }
    end

    falsy_attributes = [{ deductible_type: :percentage }, { deductible_type: nil }]
    it_behaves_like :a_falsifiable_discount_property, :unit_based?, falsy_attributes
  end

  describe "#global?" do
    subject { discount.global? }

    context "when the global field is set to true" do
      let(:discount_attributes) { { global: true } }
      it { is_expected.to be true }
    end

    falsy_attributes = [{ global: false }, { global: nil }]
    it_behaves_like :a_falsifiable_discount_property, :global?, falsy_attributes
  end

  describe "#usable?" do
    subject { discount.usable? }

    context "when the usable field is set to true" do
      let(:discount_attributes) { { usable: true } }
      it { is_expected.to be true }
    end

    falsy_attributes = [{ usable: false }, { usable: nil }]
    it_behaves_like :a_falsifiable_discount_property, :usable?, falsy_attributes
  end

  describe "#valid?" do
    subject { discount.valid? }
    merge_attributes = lambda do |attributes, **base_attributes|
      attributes.map { |attr| base_attributes.merge(attr) }
    end

    context "batch discounts -" do
      let(:base_discount_attributes) { { usable: true, application_context: :batch } }

      context "when applicable_item_count is greater than 1" do
        let(:discount_attributes) { base_discount_attributes.merge(applicable_item_count: 2) }
        it { is_expected.to be true }
      end

      falsy_attributes = [{ usable: false }, { applicable_item_count: 1 }, { applicable_item_count: 0 }]
      it_behaves_like :a_falsifiable_discount_property, :valid?,
                      merge_attributes.call(falsy_attributes, application_context: :batch)
    end

    context "single discounts -" do
      let(:base_discount_attributes) { { usable: true, application_context: :single } }

      context "when applicable_item_count is equal to 1" do
        let(:discount_attributes) { base_discount_attributes.merge(applicable_item_count: 1) }
        it { is_expected.to be true }
      end

      falsy_attributes = [{ usable: false }, { applicable_item_count: 2 }, { applicable_item_count: 0 }]
      it_behaves_like :a_falsifiable_discount_property, :valid?,
                      merge_attributes.call(falsy_attributes, application_context: :single)
    end

    context "global discounts -" do
      let(:base_discount_attributes) { { global: true, usable: true } }

      context "when deductible amount is positive" do
        let(:discount_attributes) { base_discount_attributes.merge(deductible_amount: 1) }
        it { is_expected.to be true }
      end

      falsy_attributes = [{ deductible_amount: -1 }]
      it_behaves_like :a_falsifiable_discount_property, :valid?,
                      merge_attributes.call(falsy_attributes, global: true)
    end
  end
end
