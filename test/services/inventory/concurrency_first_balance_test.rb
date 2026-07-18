# frozen_string_literal: true

require "test_helper"

module Inventory
  class ConcurrencyFirstBalanceTest < ActiveSupport::TestCase
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

    test "concurrent first stock balance creation does not abort transactions" do
      errors = []
      threads = 2.times.map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            adjustment = InventoryAdjustment.create!(
              store: @store,
              kind: "opening_inventory",
              status: "draft",
              inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
              created_by_user: @user
            )
            line = InventoryAdjustmentLine.create!(
              inventory_adjustment: adjustment,
              product_variant: @variant,
              position: 0,
              quantity_delta: 1,
              input_unit_cost_cents: 100 + i,
              input_cost_method: "explicit",
              input_cost_quality: "actual"
            )
            result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
            errors << result.error unless result.success?
          end
        rescue StandardError => e
          errors << e.message
        end
      end
      threads.each(&:join)

      assert_empty errors, errors.inspect
      assert_equal 1, StockBalance.where(store: @store, product_variant: @variant).count
      assert_equal 2, InventoryLedgerEntry.where(store: @store, product_variant: @variant).count
    end
  end
end
