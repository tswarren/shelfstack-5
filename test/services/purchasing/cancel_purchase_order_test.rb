# frozen_string_literal: true

require "test_helper"

module Purchasing
  class CancelPurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
    end

    test "cancels a draft purchase order" do
      po = purchase_orders(:draft_po)
      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store, cancel_reason: "no longer needed")

      assert result.success?, result.error
      assert po.reload.cancelled?
      assert_equal @user, po.cancelled_by_user
    end

    test "cancels an ordered purchase order with nothing received" do
      po = purchase_orders(:ordered_po)
      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store, cancel_reason: "vendor unavailable")

      assert result.success?, result.error
      assert po.reload.cancelled?
    end

    test "cannot cancel a purchase order with received quantity" do
      po = purchase_orders(:ordered_po)
      purchase_order_lines(:ordered_po_line1).update_column(:received_quantity, 1)

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/received quantity/i, result.error)
      assert po.reload.ordered?
    end

    test "cannot cancel a closed purchase order" do
      po = purchase_orders(:ordered_po)
      purchase_order_lines(:ordered_po_line1).update_column(:cancelled_quantity, 5)
      po.update!(status: "closed", closed_at: Time.current, closed_by_user: @user)

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/closed/i, result.error)
    end

    test "replaying an already-cancelled purchase order is a no-op success" do
      po = purchase_orders(:draft_po)
      assert CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store).success?

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store)
      assert result.success?
      assert result.replayed
    end
  end
end
