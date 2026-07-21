# frozen_string_literal: true

require "test_helper"

module Inventory
  class CreateReceiptTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @user = users(:admin)
      @clerk = users(:clerk)
      @variant = product_variants(:sample_book_standard)
    end

    test "assigns a store-scoped receipt number" do
      receipt = Receipt.new(vendor: @vendor)
      result = CreateReceipt.call(
        receipt: receipt,
        lines_attributes: [
          { product_variant_id: @variant.id, delivered_quantity: 3, accepted_quantity: 3,
            actual_unit_cost_cents: 700, cost_quality: "actual", cost_provenance: "vendor_source" }
        ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      assert_equal "001-RCPT-000002", result.receipt.receipt_number
      assert_equal "draft", result.receipt.status
      assert_equal 1, result.receipt.receipt_lines.count
    end

    test "increments the store sequence across multiple receipts" do
      2.times do
        result = CreateReceipt.call(
          receipt: Receipt.new(vendor: @vendor),
          lines_attributes: [ { product_variant_id: @variant.id, delivered_quantity: 1, accepted_quantity: 1 } ],
          actor: @user,
          store: @store
        )
        assert result.success?, result.error
      end

      numbers = Receipt.where(store: @store).order(:receipt_number).pluck(:receipt_number)
      assert_equal %w[001-RCPT-000001 001-RCPT-000002 001-RCPT-000003], numbers
    end

    test "fails without at least one line" do
      result = CreateReceipt.call(receipt: Receipt.new(vendor: @vendor), lines_attributes: [], actor: @user, store: @store)

      assert_not result.success?
      assert_match(/at least one line/i, result.error)
    end

    test "denies an actor without inventory.receipt.create" do
      result = CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ { product_variant_id: @variant.id, delivered_quantity: 1, accepted_quantity: 1 } ],
        actor: @clerk,
        store: @store
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end
  end
end
