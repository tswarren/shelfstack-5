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
            actual_unit_cost_cents: 700, cost_quality: "actual", cost_provenance: "manual_receipt" }
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

    test "accepts a blank cost_quality string from the form as nil when no suggestion applies" do
      other_vendor = vendors(:small_press_direct)
      result = CreateReceipt.call(
        receipt: Receipt.new(vendor: other_vendor),
        lines_attributes: [ {
          product_variant_id: @variant.id,
          delivered_quantity: 1,
          accepted_quantity: 1,
          cost_quality: ""
        } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      line = result.receipt.receipt_lines.first
      assert_nil line.cost_quality
      assert_nil line.actual_unit_cost_cents
    end

    test "defaults unit cost from vendor expected as estimated when cost is blank" do
      result = CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ {
          product_variant_id: @variant.id,
          delivered_quantity: 1,
          accepted_quantity: 1
        } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      line = result.receipt.receipt_lines.first
      assert_equal 720, line.actual_unit_cost_cents
      assert_equal "estimated", line.cost_quality
      assert_equal "vendor_source_expected", line.cost_provenance
    end

    test "preserves explicit unknown and does not refill a suggestion" do
      result = CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ {
          product_variant_id: @variant.id,
          delivered_quantity: 1,
          accepted_quantity: 1,
          cost_quality: "unknown"
        } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      line = result.receipt.receipt_lines.first
      assert_nil line.actual_unit_cost_cents
      assert_equal "unknown", line.cost_quality
      assert_equal "unknown", line.cost_provenance
    end

    test "defaults unit cost from linked purchase-order expected cost" do
      po_line = purchase_order_lines(:ordered_po_line1)
      product_variant_vendors(:sample_book_ingram).update_columns(
        expected_unit_cost_cents: 999, list_cost_cents: 2000, discount_bps: 0
      )
      po_line.update_columns(expected_unit_cost_cents: 640)

      result = CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ {
          product_variant_id: @variant.id,
          purchase_order_line_id: po_line.id,
          delivered_quantity: 1,
          accepted_quantity: 1
        } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      line = result.receipt.receipt_lines.first
      assert_equal 640, line.actual_unit_cost_cents
      assert_equal "estimated", line.cost_quality
      assert_equal "purchase_order_expected", line.cost_provenance
    end
  end
end
