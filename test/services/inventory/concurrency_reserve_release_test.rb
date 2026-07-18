# frozen_string_literal: true

require "test_helper"

module Inventory
  class ConcurrencyReserveReleaseTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      InventoryLedgerEntry.delete_all
      InventoryAdjustmentLine.delete_all
      InventoryAdjustment.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all

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
        quantity_delta: 5,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store).success?
    end

    teardown do
      InventoryLedgerEntry.delete_all
      InventoryAdjustmentLine.delete_all
      InventoryAdjustment.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all
    end

    test "concurrent reserve update and release do not deadlock" do
      first = Reserve.call(
        store: @store,
        product_variant: @variant,
        quantity: 2,
        source_type: "pos_line_item",
        source_id: 9001
      )
      assert first.success?

      errors = []
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            result = Reserve.call(
              store: @store,
              product_variant: @variant,
              quantity: 3,
              source_type: "pos_line_item",
              source_id: 9001
            )
            errors << result.error unless result.success?
          end
        rescue StandardError => e
          errors << e.message
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            reservation = InventoryReservation.active.find_by!(
              store_id: @store.id,
              product_variant_id: @variant.id,
              source_type: "pos_line_item",
              source_id: 9001
            )
            result = ReleaseReservation.call(reservation: reservation, actor: @user, release_reason: "race")
            errors << result.error unless result.success?
          end
        rescue StandardError => e
          errors << e.message
        end
      ]
      threads.each(&:join)

      assert_empty errors, errors.inspect
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_includes [ 0, 3 ], balance.reserved
    end
  end
end
