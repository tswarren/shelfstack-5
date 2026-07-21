# frozen_string_literal: true

require "test_helper"

module Pos
  class RequestReservationCoverageTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)

      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 10, reserved: 0, unavailable: 0,
        inventory_value_cents: 10_000, moving_average_cost_cents: 1000, cost_quality: "actual"
      )

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "partial POS handoff keeps coverage and completion does not double-consume request holds" do
      request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product,
        product_variant: @variant, requested_quantity: 5, requested_by_user: @admin
      )
      assert Inventory::Reserve.call(
        store: @store, product_variant: @variant, quantity: 5,
        source_type: "product_request", source_id: request.id, actor: @admin
      ).success?

      line = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, actor: @admin,
        quantity: 2, product_request: request
      ).pos_line_item

      assert line.present?
      assert_equal 5, request.reload.active_reserved_quantity
      assert_equal 3, request.request_held_reserved_quantity
      assert_equal 2, request.pos_held_reserved_quantity
      assert_equal 0, request.uncovered_quantity

      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin
      )
      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "coverage-handoff-1"
      )
      assert result.success?, result.error

      fulfillment = ProductRequestFulfillment.find_by!(pos_line_item: line, kind: "fulfill")
      assert_equal "converted", fulfillment.inventory_reservation.status
      assert_equal 2, fulfillment.quantity
      assert_equal 2, request.reload.fulfilled_quantity
      assert_equal 3, request.request_held_reserved_quantity
      assert_equal 0, request.pos_held_reserved_quantity
      assert_equal 3, request.active_reserved_quantity
      assert_equal 0, request.uncovered_quantity
    end

    test "decreasing a request-linked line returns quantity to the request reservation" do
      request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product,
        product_variant: @variant, requested_quantity: 4, requested_by_user: @admin
      )
      assert Inventory::Reserve.call(
        store: @store, product_variant: @variant, quantity: 4,
        source_type: "product_request", source_id: request.id, actor: @admin
      ).success?

      line = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, actor: @admin,
        quantity: 3, product_request: request
      ).pos_line_item

      result = UpdateLineQty.call(pos_line_item: line, quantity: 1, actor: @admin)
      assert result.success?, result.error

      assert_equal 4, request.reload.active_reserved_quantity
      assert_equal 3, request.request_held_reserved_quantity
      assert_equal 1, request.pos_held_reserved_quantity
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 4, balance.reserved
    end
  end
end
