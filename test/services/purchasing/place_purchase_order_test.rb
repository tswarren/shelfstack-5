# frozen_string_literal: true

require "test_helper"

module Purchasing
  class PlacePurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @po = purchase_orders(:draft_po)
    end

    test "places a draft purchase order and records placement user/time" do
      result = PlacePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert result.success?, result.error
      assert_not result.replayed
      assert @po.reload.ordered?
      assert_equal @user, @po.ordered_by_user
      assert_not_nil @po.ordered_at
      assert_not_nil @po.ordered_on
    end

    test "replaying an already-ordered purchase order is a no-op success" do
      po = purchase_orders(:ordered_po)
      before = AdministrativeAuditEvent.where(action: "purchasing.purchase_order.placed").count

      result = PlacePurchaseOrder.call(purchase_order: po, actor: @user, store: @store)

      assert result.success?
      assert result.replayed
      assert_equal before, AdministrativeAuditEvent.where(action: "purchasing.purchase_order.placed").count
    end

    test "rejects placement when vendor is inactive" do
      @po.vendor.update_column(:active, false)

      result = PlacePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/vendor must be active/i, result.error)
      assert @po.reload.draft?
    end

    test "rejects placement with no lines" do
      @po.purchase_order_lines.destroy_all

      result = PlacePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/at least one line/i, result.error)
    end

    test "warns when quantity is below the vendor minimum order quantity" do
      line = purchase_order_lines(:draft_po_line1)
      line.product_variant_vendor.update!(minimum_order_quantity: 100)

      result = PlacePurchaseOrder.call(purchase_order: @po, actor: @user, store: @store)

      assert result.success?, result.error
      assert result.warnings.any? { |w| w.match?(/minimum order quantity/i) }
    end
  end
end
