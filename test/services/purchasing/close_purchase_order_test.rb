# frozen_string_literal: true

require "test_helper"

module Purchasing
  class ClosePurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @po = purchase_orders(:ordered_po)
      @line = purchase_order_lines(:ordered_po_line1)
    end

    test "cannot close while open quantity remains" do
      result = ClosePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/received or cancelled/i, result.error)
    end

    test "closes once all line quantity is received or cancelled" do
      @line.update_column(:cancelled_quantity, @line.ordered_quantity)

      result = ClosePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert result.success?, result.error
      assert @po.reload.closed?
      assert_equal @user, @po.closed_by_user
    end

    test "refuses to close while remaining allocations exist" do
      request = product_requests(:open_customer_request)
      assert CreateAllocation.call(
        purchase_order_line: @line, product_request: request, quantity: 1, actor: @user, store: @store
      ).success?
      # Drive open quantity to zero without cancel-PO allocation release so the
      # remaining allocation is the sole close blocker.
      @line.update_columns(cancelled_quantity: @line.ordered_quantity, received_quantity: 0)

      result = ClosePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/allocated quantity remains/i, result.error)
      refute @po.reload.closed?
    end

    test "only ordered purchase orders can be closed" do
      draft = purchase_orders(:draft_po)

      result = ClosePurchaseOrder.call(purchase_order: draft, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/only ordered purchase orders/i, result.error)
    end

    test "replaying an already-closed purchase order is a no-op success" do
      @line.update_column(:cancelled_quantity, @line.ordered_quantity)
      assert ClosePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store).success?

      result = ClosePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)
      assert result.success?
      assert result.replayed
    end
  end
end
