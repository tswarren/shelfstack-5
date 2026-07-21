# frozen_string_literal: true

require "test_helper"

module Requests
  class ReserveInHouseInventoryTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @variant = product_variants(:sample_book_standard)
      pos_open_inventory(store: @store, variant: @variant, quantity: 5, unit_cost_cents: 700, actor: @admin)
      @request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product, product_variant: @variant,
        requested_quantity: 3, requested_by_user: @admin
      )
    end

    test "reserves physically confirmed on-hand inventory for the request" do
      result = ReserveInHouseInventory.call(product_request: @request, quantity: 2, actor: @admin, store: @store, physically_confirmed: true)

      assert result.success?, result.error
      reservation = result.reservation
      assert_equal "product_request", reservation.source_type
      assert_equal @request.id, reservation.source_id
      assert_equal 2, reservation.quantity

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 2, balance.reserved
      assert_equal 1, @request.reload.uncovered_quantity
    end

    test "requires explicit physical confirmation" do
      result = ReserveInHouseInventory.call(product_request: @request, quantity: 1, actor: @admin, store: @store, physically_confirmed: false)

      assert_not result.success?
      assert_match(/physical confirmation/i, result.error)
      refute InventoryReservation.exists?(source_type: "product_request", source_id: @request.id)
    end

    test "defaults physically_confirmed to false when omitted" do
      result = ReserveInHouseInventory.call(product_request: @request, quantity: 1, actor: @admin, store: @store)

      assert_not result.success?
      assert_match(/physical confirmation/i, result.error)
    end

    test "accumulates additional quantity onto an existing active reservation" do
      first = ReserveInHouseInventory.call(product_request: @request, quantity: 1, actor: @admin, store: @store, physically_confirmed: true)
      assert first.success?, first.error

      second = ReserveInHouseInventory.call(product_request: @request, quantity: 2, actor: @admin, store: @store, physically_confirmed: true)
      assert second.success?, second.error
      assert_equal first.reservation.id, second.reservation.id
      assert_equal 3, second.reservation.reload.quantity
    end

    test "caps quantity at the product request's uncovered quantity" do
      result = ReserveInHouseInventory.call(product_request: @request, quantity: 4, actor: @admin, store: @store, physically_confirmed: true)

      assert_not result.success?
      assert_match(/uncovered quantity/i, result.error)
    end

    test "rejects non-customer requests" do
      staff_request = ProductRequest.create!(
        store: @store, request_type: "staff_suggestion", product: @variant.product, product_variant: @variant,
        requested_quantity: 2, requested_by_user: @admin
      )

      result = ReserveInHouseInventory.call(product_request: staff_request, quantity: 1, actor: @admin, store: @store, physically_confirmed: true)

      assert_not result.success?
      assert_match(/customer requests/i, result.error)
    end

    test "denies an actor without requests.customer_request.reserve" do
      result = ReserveInHouseInventory.call(product_request: @request, quantity: 1, actor: @clerk, store: @store, physically_confirmed: true)

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "records an audit event" do
      result = ReserveInHouseInventory.call(product_request: @request, quantity: 2, actor: @admin, store: @store, physically_confirmed: true)

      assert result.success?, result.error
      event = AdministrativeAuditEvent.where(action: "requests.customer_request.reserved", subject_id: @request.id).last
      assert event
      assert_equal 2, event.metadata["quantity"]
    end

    test "unclaimed in-house reservations release via the existing inventory.reservation.release path" do
      reserved = ReserveInHouseInventory.call(product_request: @request, quantity: 2, actor: @admin, store: @store, physically_confirmed: true)
      assert reserved.success?, reserved.error
      assert_equal 1, @request.reload.uncovered_quantity

      release = Inventory::ReleaseReservation.call(reservation: reserved.reservation, actor: @admin, release_reason: "unclaimed")
      assert release.success?, release.error
      assert_equal "released", release.reservation.status

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 0, balance.reserved

      @request.reload
      assert @request.open?
      assert_equal 3, @request.uncovered_quantity
    end
  end
end
