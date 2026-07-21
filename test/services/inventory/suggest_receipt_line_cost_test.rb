# frozen_string_literal: true

require "test_helper"

module Inventory
  class SuggestReceiptLineCostTest < ActiveSupport::TestCase
    setup do
      @po_line = purchase_order_lines(:ordered_po_line1)
      @vendor = vendors(:acme_distributor)
      @variant = product_variants(:sample_book_standard)
      @source = product_variant_vendors(:sample_book_ingram)
    end

    test "prefers vendor-source expected unit cost" do
      suggestion = SuggestReceiptLineCost.call(purchase_order_line: @po_line)

      assert_equal 720, suggestion.unit_cost_cents
      assert_equal "actual", suggestion.cost_quality
      assert_equal "vendor_source", suggestion.cost_provenance
    end

    test "falls back to list minus discount when expected is blank" do
      @source.update_columns(expected_unit_cost_cents: nil, list_cost_cents: 1000, discount_bps: 2500)
      @po_line.update_columns(product_variant_vendor_id: @source.id, expected_unit_cost_cents: 999)

      suggestion = SuggestReceiptLineCost.call(
        purchase_order_line: nil,
        product_variant: @variant,
        vendor: @vendor
      )

      assert_equal 750, suggestion.unit_cost_cents
      assert_equal "estimated", suggestion.cost_quality
      assert_equal "vendor_list_discount", suggestion.cost_provenance
    end

    test "falls back to purchase-order expected cost" do
      @source.update_columns(expected_unit_cost_cents: nil, list_cost_cents: nil, discount_bps: nil)
      @po_line.update_columns(product_variant_vendor_id: nil, expected_unit_cost_cents: 640)

      suggestion = SuggestReceiptLineCost.call(purchase_order_line: @po_line.reload)

      assert_equal 640, suggestion.unit_cost_cents
      assert_equal "estimated", suggestion.cost_quality
      assert_equal "purchase_order_expected", suggestion.cost_provenance
    end

    test "returns nil when no cost basis exists" do
      suggestion = SuggestReceiptLineCost.call(
        product_variant: product_variants(:upc_product_standard),
        vendor: vendors(:small_press_direct)
      )

      assert_nil suggestion
    end
  end
end
