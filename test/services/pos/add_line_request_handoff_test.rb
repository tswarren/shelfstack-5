# frozen_string_literal: true

require "test_helper"

module Pos
  class AddLineRequestHandoffTest < ActiveSupport::TestCase
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
    end

    test "transfers a quantity request reservation to the POS line without double-reserving" do
      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 5000, moving_average_cost_cents: 1000, cost_quality: "actual"
      )
      request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product,
        product_variant: @variant, requested_quantity: 2, requested_by_user: @admin
      )
      assert Inventory::Reserve.call(
        store: @store, product_variant: @variant, quantity: 2,
        source_type: "product_request", source_id: request.id, actor: @admin
      ).success?

      result = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, actor: @admin,
        quantity: 2, product_request: request
      )

      assert result.success?, result.error
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 2, balance.reserved
      refute InventoryReservation.active.exists?(source_type: "product_request", source_id: request.id)
      assert InventoryReservation.active.exists?(
        source_type: "pos_line_item", source_id: result.pos_line_item.id, quantity: 2
      )
    end

    test "transfers an individual request reservation to the POS line" do
      individual = product_variants(:signed_book_standard)
      unit = InventoryUnit.create!(
        store: @store, product_variant: individual, status: "available",
        unit_identifier: "2700000000991", created_by_user: @admin, acquired_at: Time.current,
        acquisition_cost_cents: 2000
      )
      request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: individual.product,
        product_variant: individual, requested_quantity: 1, requested_by_user: @admin
      )
      assert Inventory::Reserve.call(
        store: @store, product_variant: individual, quantity: 1,
        source_type: "product_request", source_id: request.id,
        inventory_unit: unit, actor: @admin
      ).success?

      result = AddLine.call(
        pos_transaction: @transaction, product_variant: individual, actor: @admin,
        quantity: 1, inventory_unit: unit, product_request: request
      )

      assert result.success?, result.error
      reservation = InventoryReservation.active.find_by!(inventory_unit_id: unit.id)
      assert_equal "pos_line_item", reservation.source_type
      assert_equal result.pos_line_item.id, reservation.source_id
      assert_equal "reserved", unit.reload.status
    end
  end
end
