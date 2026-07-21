# frozen_string_literal: true

require "test_helper"

module Purchasing
  class ApplyBulkDiscountToDraftLinesTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @po = purchase_orders(:draft_po)
      @line = purchase_order_lines(:draft_po_line1)
    end

    test "updates discount and recomputes expected cost deterministically" do
      result = ApplyBulkDiscountToDraftLines.call(
        purchase_order: @po, line_ids: [ @line.id ], discount_bps: 5000, actor: @user, store: @store
      )

      assert result.success?, result.error
      @line.reload
      assert_equal 5000, @line.discount_bps
      assert_equal 600, @line.expected_unit_cost_cents
      assert_equal "bulk_discount_update", @line.cost_provenance
    end

    test "only affects draft purchase orders" do
      po = purchase_orders(:ordered_po)
      line = purchase_order_lines(:ordered_po_line1)

      result = ApplyBulkDiscountToDraftLines.call(
        purchase_order: po, line_ids: [ line.id ], discount_bps: 5000, actor: @user, store: @store
      )

      assert_not result.success?
      assert_match(/only draft/i, result.error)
    end

    test "ignores direct_net_cost lines" do
      line = @po.purchase_order_lines.create!(
        product_variant: product_variants(:upc_product_standard), ordered_quantity: 1, position: 1,
        cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 500
      )

      result = ApplyBulkDiscountToDraftLines.call(
        purchase_order: @po, line_ids: [ line.id ], discount_bps: 5000, actor: @user, store: @store
      )

      assert_not result.success?
      assert_match(/no eligible/i, result.error)
    end

    test "denies an actor without purchasing.cost.view" do
      clerk = users(:clerk)

      result = ApplyBulkDiscountToDraftLines.call(
        purchase_order: @po, line_ids: [ @line.id ], discount_bps: 5000, actor: clerk, store: @store
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
      assert_equal 4000, @line.reload.discount_bps
    end
  end
end
