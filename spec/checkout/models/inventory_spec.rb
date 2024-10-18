# frozen_string_literal: true

require "checkout/models/inventory"
require "checkout/core/inventory_builder"
require "checkout/models/discount"

RSpec.describe Checkout::Models::Inventory do
  let(:fixture_path) { File.join(File.dirname(__FILE__), "../../fixtures/inventory.yml") }
  let(:inventory) { Checkout::Core::InventoryBuilder.new(fixture_path).build }
  let(:file_writer_stub) { instance_double(File) }

  before do
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(fixture_path, "w").and_yield(file_writer_stub)
    allow(file_writer_stub).to receive(:write)
  end

  describe "#add_item" do
    context "when sent valid item attributes (attributes with all keys present)" do
      let(:item_attributes) { { id: 4, name: "D", cost: 60 } }
      let(:new_entry) do
        inventory.items.find { |item| item.id == item_attributes[:id] }
      end

      context "without persisting file changes" do
        it "adds the item to its internal store of items" do
          aggregate_failures do
            expect { inventory.add_item(item_attributes) }
              .to change { inventory.items.count }.by(1)
            expect(new_entry).not_to be_nil
          end
        end
      end

      context "with changes being persisted to the source source file" do
        subject { inventory.add_item(item_attributes, persist: true) }

        it "adds the item to the store and writes to file" do
          aggregate_failures do
            expect { subject }.to change { inventory.items.count }.by(1)
            expect(new_entry).not_to be_nil
            expect(file_writer_stub).to have_received(:write)
          end
        end
      end
    end

    context "when invalid item attributes are sent" do
      subject { inventory.add_item(item_attributes, persist: true) }
      let(:item_attributes) { { id: 4, name: "D", cost: 60 }.except(%i[name id cost].sample) }

      it "does not add the item to the store" do
        aggregate_failures do
          expect { subject }.not_to(change { inventory.items.count })
          expect(file_writer_stub).not_to have_received(:write)
        end
      end
    end
  end

  describe "#find_item" do
    subject { inventory.find_item("A") }

    context "when the item exists in the inventory" do
      it "returns the matching inventory item" do
        aggregate_failures do
          expect(subject).not_to be_nil
          expect(subject.name).to eq("A")
        end
      end
    end
  end

  describe "#add_discount" do
    let(:base_discount_attributes) do
      Checkout::Models::Discount
        .base_discount_attributes
        .merge(applicable_item_id: 5, name: :test_discount)
    end

    context "when sent valid discount attributes (attributes with all keys present)" do
      let(:discount_attributes) { base_discount_attributes }

      let(:new_entry) do
        inventory.discounts.find { |discount| discount.name == :test_discount }
      end

      context "without persisting file changes" do
        it "adds the discount to its discounts field" do
          aggregate_failures do
            expect { inventory.add_discount(discount_attributes) }
              .to change { inventory.discounts.count }.by(1)
            expect(new_entry).not_to be_nil
          end
        end
      end

      context "with changes being persisted to the source source file" do
        subject { inventory.add_discount(discount_attributes, persist: true) }

        it "adds the discount to the store and writes to file" do
          aggregate_failures do
            expect { subject }.to change { inventory.discounts.count }.by(1)
            expect(new_entry).not_to be_nil
            expect(file_writer_stub).to have_received(:write)
          end
        end
      end
    end

    context "when invalid item attributes are sent" do
      subject { inventory.add_item(discount_attributes, persist: true) }

      let(:discount_attributes) do
        base_discount_attributes.except(Checkout::Models::DISCOUNT_KEYS.sample)
      end

      it "does not add the discount to the store" do
        aggregate_failures do
          expect { subject }.not_to(change { inventory.discounts.count })
          expect(file_writer_stub).not_to have_received(:write)
        end
      end
    end
  end
end
