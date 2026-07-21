# frozen_string_literal: true

require "test_helper"

module Pos
  class CancelTransactionRequestHoldTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 5000, moving_average_cost_cents: 1000, cost_quality: "actual"
      )
      @request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product,
        product_variant: @variant, requested_quantity: 2, requested_by_user: @admin
      )
      assert Inventory::Reserve.call(
        store: @store, product_variant: @variant, quantity: 2,
        source_type: "product_request", source_id: @request.id, actor: @admin
      ).success?

      result = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, actor: @admin,
        quantity: 2, product_request: @request
      )
      assert result.success?, result.error
      @line = result.pos_line_item
    end

    test "cancel returns POS reservation to the open product request" do
      refute InventoryReservation.active.exists?(source_type: "product_request", source_id: @request.id)
      assert InventoryReservation.active.exists?(source_type: "pos_line_item", source_id: @line.id)

      cancelled = CancelTransaction.call(
        pos_transaction: @transaction, actor: @admin, reason: "customer left"
      )
      assert cancelled.success?, cancelled.error

      assert @transaction.reload.cancelled?
      assert @line.reload.removed?
      assert @request.reload.open?

      reservation = InventoryReservation.active.find_by!(
        source_type: "product_request", source_id: @request.id
      )
      assert_equal 2, reservation.quantity
      refute InventoryReservation.active.exists?(source_type: "pos_line_item", source_id: @line.id)

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 2, balance.reserved
    end
  end
end
