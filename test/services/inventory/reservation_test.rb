# frozen_string_literal: true

require "test_helper"

module Inventory
  class ReservationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @variant = product_variants(:sample_book_standard)
      @user = users(:admin)

      adjustment = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @user
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 2,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
    end

    test "reserve updates active reservation quantity in place" do
      result = Reserve.call(
        store: @store,
        product_variant: @variant,
        quantity: 1,
        source_type: "pos_line_item",
        source_id: 101
      )
      assert result.success?
      assert_equal 1, result.stock_balance.reserved

      result = Reserve.call(
        store: @store,
        product_variant: @variant,
        quantity: 2,
        source_type: "pos_line_item",
        source_id: 101
      )
      assert result.success?
      assert_equal 1, InventoryReservation.active.where(source_type: "pos_line_item", source_id: 101).count
      assert_equal 2, result.stock_balance.reserved
    end

    test "warns when available goes negative" do
      result = Reserve.call(
        store: @store,
        product_variant: @variant,
        quantity: 5,
        source_type: "pos_line_item",
        source_id: 202
      )
      assert result.success?
      assert_includes result.warnings.join, "negative"
      assert_equal(-3, result.stock_balance.available)
    end

    test "released source can create a new active reservation" do
      first = Reserve.call(
        store: @store,
        product_variant: @variant,
        quantity: 1,
        source_type: "pos_line_item",
        source_id: 303
      )
      assert first.success?

      release = ReleaseReservation.call(reservation: first.reservation, actor: @user, release_reason: "line removed")
      assert release.success?
      assert_equal 0, StockBalance.find_by!(store: @store, product_variant: @variant).reserved

      second = Reserve.call(
        store: @store,
        product_variant: @variant,
        quantity: 1,
        source_type: "pos_line_item",
        source_id: 303
      )
      assert second.success?
      assert_equal 2, InventoryReservation.where(source_type: "pos_line_item", source_id: 303).count
      assert_equal 1, InventoryReservation.active.where(source_type: "pos_line_item", source_id: 303).count
    end

    test "release is idempotent" do
      reserved = Reserve.call(
        store: @store,
        product_variant: @variant,
        quantity: 1,
        source_type: "pos_line_item",
        source_id: 404
      )
      first = ReleaseReservation.call(reservation: reserved.reservation, actor: @user)
      second = ReleaseReservation.call(reservation: reserved.reservation.reload, actor: @user)
      assert first.success?
      assert second.success?
      assert second.replayed
      assert_equal 0, StockBalance.find_by!(store: @store, product_variant: @variant).reserved
    end
  end
end
