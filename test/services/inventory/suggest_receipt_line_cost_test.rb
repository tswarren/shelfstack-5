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

    test "linked line prefers PO expected snapshot over current vendor source" do
      @source.update_columns(expected_unit_cost_cents: 800, list_cost_cents: 1000, discount_bps: 0)
      @po_line.update_columns(expected_unit_cost_cents: 640, list_cost_cents: 1200, discount_bps: 4000)

      suggestion = SuggestReceiptLineCost.call(purchase_order_line: @po_line.reload)

      assert_equal 640, suggestion.unit_cost_cents
      assert_equal "estimated", suggestion.cost_quality
      assert_equal "purchase_order_expected", suggestion.cost_provenance
    end

    test "linked line falls back to PO list minus discount when expected blank" do
      @po_line.define_singleton_method(:expected_unit_cost_cents) { nil }
      @po_line.define_singleton_method(:list_cost_cents) { 1000 }
      @po_line.define_singleton_method(:discount_bps) { 2500 }
      @source.update_columns(expected_unit_cost_cents: 999, list_cost_cents: 2000, discount_bps: 0)

      suggestion = SuggestReceiptLineCost.call(purchase_order_line: @po_line)

      assert_equal 750, suggestion.unit_cost_cents
      assert_equal "estimated", suggestion.cost_quality
      assert_equal "purchase_order_list_discount", suggestion.cost_provenance
    end

    test "unlinked line uses vendor expected as estimated only" do
      suggestion = SuggestReceiptLineCost.call(
        purchase_order_line: nil,
        product_variant: @variant,
        vendor: @vendor
      )

      assert_equal 720, suggestion.unit_cost_cents
      assert_equal "estimated", suggestion.cost_quality
      assert_equal "vendor_source_expected", suggestion.cost_provenance
    end

    test "unlinked line falls back to vendor list minus discount" do
      @source.update_columns(expected_unit_cost_cents: nil, list_cost_cents: 1000, discount_bps: 2500)

      suggestion = SuggestReceiptLineCost.call(
        product_variant: @variant,
        vendor: @vendor
      )

      assert_equal 750, suggestion.unit_cost_cents
      assert_equal "estimated", suggestion.cost_quality
      assert_equal "vendor_list_discount", suggestion.cost_provenance
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
