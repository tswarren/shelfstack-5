# frozen_string_literal: true

require "test_helper"

module Requests
  class CancelProductRequestTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @request = product_requests(:open_stock_replenishment)
    end

    test "cancels an open request" do
      result = CancelProductRequest.call(
        product_request: @request, actor: @admin, store: @store, cancellation_reason: "No longer needed"
      )

      assert result.success?, result.error
      assert_not result.replayed
      assert_equal "cancelled", result.product_request.status
      assert_equal "No longer needed", result.product_request.resolution_note
      assert_nil result.product_request.resolution
    end

    test "replaying cancellation on an already-cancelled request is a no-op success" do
      first = CancelProductRequest.call(product_request: @request, actor: @admin, store: @store)
      assert first.success?

      second = CancelProductRequest.call(product_request: @request, actor: @admin, store: @store)
      assert second.success?
      assert second.replayed
    end

    test "refuses to cancel a closed request" do
      result = CancelProductRequest.call(
        product_request: product_requests(:resolved_frontlist), actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/only open requests/i, result.error)
    end

    test "denies an actor without requests.product_request.cancel" do
      result = CancelProductRequest.call(product_request: @request, actor: @clerk, store: @store)

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "releases active reservations and remaining allocations for a customer request" do
      variant = product_variants(:sample_book_standard)
      request = product_requests(:open_customer_request)
      request.update!(product_variant: variant)

      StockBalance.create!(
        store: @store, product_variant: variant,
        on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 5000, moving_average_cost_cents: 1000, cost_quality: "actual"
      )
      reserve = Requests::ReserveInHouseInventory.call(
        product_request: request, quantity: 1, actor: @admin, store: @store, physically_confirmed: true
      )
      assert reserve.success?, reserve.error

      vendor = vendors(:acme_distributor)
      po = Purchasing::CreatePurchaseOrder.call(
        purchase_order: PurchaseOrder.new(vendor: vendor),
        lines_attributes: [ {
          product_variant_id: variant.id, ordered_quantity: 3,
          cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 700
        } ],
        actor: @admin, store: @store
      ).purchase_order
      Purchasing::PlacePurchaseOrder.call(purchase_order: po, actor: @admin, store: @store)
      allocation = Purchasing::CreateAllocation.call(
        purchase_order_line: po.purchase_order_lines.first,
        product_request: request, quantity: 1, actor: @admin, store: @store
      ).purchase_order_allocation
      assert_predicate allocation.remaining_quantity, :positive?

      result = CancelProductRequest.call(
        product_request: request, actor: @admin, store: @store, cancellation_reason: "Customer withdrew"
      )

      assert result.success?, result.error
      assert_equal "cancelled", request.reload.status
      refute InventoryReservation.active.exists?(source_type: "product_request", source_id: request.id)
      assert_equal 0, allocation.reload.remaining_quantity
      assert_equal "request_cancelled", allocation.purchase_order_allocation_events.where(event_type: "released").sole.reason
    end

    test "rejects cancellation while a pending POS line is linked to the request" do
      variant = product_variants(:sample_book_standard)
      request = product_requests(:open_customer_request)
      request.update!(product_variant: variant, requested_quantity: 2)

      StockBalance.create!(
        store: @store, product_variant: variant,
        on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 5000, moving_average_cost_cents: 1000, cost_quality: "actual"
      )
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: pos_devices(:register_1),
        cash_drawer: cash_drawers(:drawer_1), opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      assert Pos::AddLine.call(
        pos_transaction: txn, product_variant: variant, quantity: 1, actor: @admin, product_request: request
      ).success?

      result = CancelProductRequest.call(
        product_request: request, actor: @admin, store: @store, cancellation_reason: "Customer withdrew"
      )

      assert_not result.success?
      assert_match(/pending POS lines/i, result.error)
      assert_equal "open", request.reload.status
      assert InventoryReservation.active.exists?(source_type: "pos_line_item")
    end
  end
end
