# frozen_string_literal: true

require "test_helper"

module Inventory
  class ResolveReceiptLineCostTest < ActiveSupport::TestCase
    setup do
      @po_line = purchase_order_lines(:ordered_po_line1)
      @vendor = vendors(:acme_distributor)
      @variant = product_variants(:sample_book_standard)
      @source = product_variant_vendors(:sample_book_ingram)
    end

    test "linked malformed PO without expected uses PO list discount before vendor" do
      po_line = PurchaseOrderLine.new(
        purchase_order: @po_line.purchase_order,
        product_variant: @variant,
        product_variant_vendor: @source,
        list_cost_cents: 1000,
        discount_bps: 2500,
        expected_unit_cost_cents: nil
      )
      @source.update_columns(expected_unit_cost_cents: 999, list_cost_cents: 2000, discount_bps: 0)

      resolved = ResolveReceiptLineCost.call(purchase_order_line: po_line, suggest_only: true)

      assert_equal 750, resolved.unit_cost_cents
      assert_equal "estimated", resolved.cost_quality
      assert_equal "purchase_order_list_discount", resolved.cost_provenance
      assert_equal "configured_estimate", resolved.ledger_cost_method
    end

    test "linked PO without cost snapshots falls back to vendor expected as estimate" do
      po_line = PurchaseOrderLine.new(
        purchase_order: @po_line.purchase_order,
        product_variant: @variant,
        product_variant_vendor: @source,
        expected_unit_cost_cents: nil,
        list_cost_cents: nil,
        discount_bps: nil
      )
      @source.update_columns(expected_unit_cost_cents: 810)

      resolved = ResolveReceiptLineCost.call(purchase_order_line: po_line, suggest_only: true)

      assert_equal 810, resolved.unit_cost_cents
      assert_equal "estimated", resolved.cost_quality
      assert_equal "vendor_source_expected", resolved.cost_provenance
    end

    test "explicit unknown on the receipt line is preserved" do
      line = ReceiptLine.new(cost_quality: "unknown", actual_unit_cost_cents: 500)

      resolved = ResolveReceiptLineCost.call(receipt_line: line)

      assert_nil resolved.unit_cost_cents
      assert_equal "unknown", resolved.cost_quality
      assert_equal "unknown", resolved.ledger_cost_method
    end
  end
end
