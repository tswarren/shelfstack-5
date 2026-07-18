# frozen_string_literal: true

require "test_helper"

module Inventory
  class ConcurrencyTest < ActiveSupport::TestCase
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
    end

    teardown do
      InventoryLedgerEntry.delete_all
      InventoryAdjustmentLine.delete_all
      InventoryAdjustment.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all
    end

    test "concurrent quantity-only posts serialize via balance lock" do
      open_stock!(qty: 10, unit_cost: 100)

      threads = 2.times.map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            adjustment = InventoryAdjustment.create!(
              store: @store,
              kind: "quantity_only",
              status: "draft",
              inventory_adjustment_reason: inventory_adjustment_reasons(:quantity_shortage),
              created_by_user: @user
            )
            InventoryAdjustmentLine.create!(
              inventory_adjustment: adjustment,
              product_variant: @variant,
              position: 0,
              quantity_delta: -1
            )
            PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
          end
        end
      end
      threads.each(&:join)

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 8, balance.on_hand
      assert_equal 2, InventoryLedgerEntry.where(movement_type: "quantity_adjustment").count
    end

    private

    def open_stock!(qty:, unit_cost:)
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
        quantity_delta: qty,
        input_unit_cost_cents: unit_cost,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      raise result.error unless result.success?
    end
  end
end
