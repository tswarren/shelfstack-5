# frozen_string_literal: true

require "test_helper"

module Purchasing
  class UpdateDraftPurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @po = purchase_orders(:draft_po)
      @variant = product_variants(:sample_book_standard)
    end

    test "replaces lines on a draft purchase order" do
      result = UpdateDraftPurchaseOrder.call(
        purchase_order: @po,
        attributes: { vendor_reference: "REF-42" },
        lines_attributes: [ { product_variant_id: @variant.id, ordered_quantity: 6,
                               cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 500 } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      assert_equal "REF-42", result.purchase_order.vendor_reference
      assert_equal 1, result.purchase_order.purchase_order_lines.count
      assert_equal 6, result.purchase_order.purchase_order_lines.first.ordered_quantity
    end

    test "cannot update an ordered purchase order" do
      po = purchase_orders(:ordered_po)

      result = UpdateDraftPurchaseOrder.call(
        purchase_order: po,
        attributes: { vendor_reference: "REF-99" },
        lines_attributes: [],
        actor: @user,
        store: @store
      )

      assert_not result.success?
      assert_match(/only draft/i, result.error)
    end

    test "preserves protected cost fields when can_edit_cost is false" do
      line = purchase_order_lines(:draft_po_line1)
      original_cost = line.expected_unit_cost_cents
      original_list = line.list_cost_cents
      original_discount = line.discount_bps

      result = UpdateDraftPurchaseOrder.call(
        purchase_order: @po,
        attributes: {},
        lines_attributes: [ {
          id: line.id, product_variant_id: line.product_variant_id, ordered_quantity: 8,
          cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 1
        } ],
        actor: @user,
        store: @store,
        can_edit_cost: false
      )

      assert result.success?, result.error
      line.reload
      assert_equal 8, line.ordered_quantity
      assert_equal original_cost, line.expected_unit_cost_cents
      assert_equal original_list, line.list_cost_cents
      assert_equal original_discount, line.discount_bps
      assert_equal "discount_from_list", line.cost_entry_method
    end
  end
end
