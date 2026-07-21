# frozen_string_literal: true

require "test_helper"

module Purchasing
  class AmendPurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @po = purchase_orders(:ordered_po)
      @line = purchase_order_lines(:ordered_po_line1)
      @variant = product_variants(:sample_book_standard)
    end

    test "cancelling remaining quantity requires a reason" do
      result = AmendPurchaseOrder.call(
        purchase_order: @po, actor: @user, store: @store,
        cancel_lines_attributes: [ { id: @line.id, cancelled_quantity: 2 } ],
        reason: nil
      )

      assert_not result.success?
      assert_match(/reason is required/i, result.error)
      assert_equal 0, @line.reload.cancelled_quantity
    end

    test "cancels remaining ordered quantity with a reason" do
      result = AmendPurchaseOrder.call(
        purchase_order: @po, actor: @user, store: @store,
        cancel_lines_attributes: [ { id: @line.id, cancelled_quantity: 2 } ],
        reason: "Vendor discontinued title"
      )

      assert result.success?, result.error
      assert_equal 2, @line.reload.cancelled_quantity
      event = AdministrativeAuditEvent.where(action: "purchasing.purchase_order.amended").last
      assert_equal "Vendor discontinued title", event.metadata["reason"]
    end

    test "cancelled_quantity cannot decrease via amend" do
      @line.update_column(:cancelled_quantity, 2)

      result = AmendPurchaseOrder.call(
        purchase_order: @po, actor: @user, store: @store,
        cancel_lines_attributes: [ { id: @line.id, cancelled_quantity: 1 } ],
        reason: "typo"
      )

      assert_not result.success?
      assert_match(/cannot decrease/i, result.error)
    end

    test "increases supply by adding a new line" do
      result = AmendPurchaseOrder.call(
        purchase_order: @po, actor: @user, store: @store,
        new_lines_attributes: [ { product_variant_id: @variant.id, ordered_quantity: 4,
                                   cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 600 } ]
      )

      assert result.success?, result.error
      assert_equal 2, @po.reload.purchase_order_lines.count
    end

    test "only ordered purchase orders can be amended" do
      draft = purchase_orders(:draft_po)

      result = AmendPurchaseOrder.call(
        purchase_order: draft, actor: @user, store: @store,
        new_lines_attributes: [ { product_variant_id: @variant.id, ordered_quantity: 1,
                                   cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 100 } ]
      )

      assert_not result.success?
      assert_match(/only ordered purchase orders/i, result.error)
    end

    test "amend with no changes fails" do
      result = AmendPurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/cancel quantity or add/i, result.error)
    end
  end
end
