# frozen_string_literal: true

require "test_helper"

module Inventory
  class UnitReservationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @variant = product_variants(:signed_book_standard)
      @user = users(:admin)
      @unit = CreateInventoryUnit.call(
        store: @store, product_variant: @variant, actor: @user, acquisition_cost_cents: 800
      ).inventory_unit
    end

    test "reserve marks the unit reserved and creates an active reservation" do
      result = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 501, inventory_unit: @unit
      )

      assert result.success?, result.error
      assert_equal @unit, result.reservation.inventory_unit
      assert_equal "reserved", @unit.reload.status
      assert_equal 1, InventoryReservation.active.where(inventory_unit_id: @unit.id).count
    end

    test "reserving an already-reserved unit from a different source fails" do
      first = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 601, inventory_unit: @unit
      )
      assert first.success?

      second = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 602, inventory_unit: @unit
      )

      refute second.success?
      assert_match(/already reserved|not available/, second.error)
      assert_equal "reserved", @unit.reload.status
    end

    test "reserving the same source twice for the same unit is idempotent" do
      first = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 701, inventory_unit: @unit
      )
      second = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 701, inventory_unit: @unit
      )

      assert first.success?
      assert second.success?
      assert_equal first.reservation.id, second.reservation.id
    end

    test "release restores the unit to available" do
      reserved = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 801, inventory_unit: @unit
      )

      release = ReleaseReservation.call(reservation: reserved.reservation, actor: @user, release_reason: "line removed")

      assert release.success?
      assert_equal "available", @unit.reload.status
      assert_equal "released", reserved.reservation.reload.status
    end

    test "release is idempotent for unit reservations" do
      reserved = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 901, inventory_unit: @unit
      )

      first = ReleaseReservation.call(reservation: reserved.reservation, actor: @user)
      second = ReleaseReservation.call(reservation: reserved.reservation.reload, actor: @user)

      assert first.success?
      assert second.success?
      assert second.replayed
      assert_equal "available", @unit.reload.status
    end

    test "a released unit can be reserved again by another source" do
      first = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 1001, inventory_unit: @unit
      )
      ReleaseReservation.call(reservation: first.reservation, actor: @user)

      second = Reserve.call(
        store: @store, product_variant: @variant, quantity: 1,
        source_type: "pos_line_item", source_id: 1002, inventory_unit: @unit
      )

      assert second.success?
      assert_equal "reserved", @unit.reload.status
    end

    test "reserve requires quantity 1 for individually tracked units" do
      result = Reserve.call(
        store: @store, product_variant: @variant, quantity: 2,
        source_type: "pos_line_item", source_id: 1101, inventory_unit: @unit
      )

      refute result.success?
      assert_match(/quantity must be 1/, result.error)
    end
  end
end
