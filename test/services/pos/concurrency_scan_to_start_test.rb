# frozen_string_literal: true

require "test_helper"

module Pos
  class ConcurrencyScanToStartTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      cleanup_operational!
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
    end

    teardown { cleanup_operational! }

    test "concurrent scan-to-start creates one open transaction" do
      results = {}
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:a] = ScanToStart.call(
              pos_session: @session, actor: @admin, query: @variant.sku, quantity: 1
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:b] = ScanToStart.call(
              pos_session: @session, actor: @admin, query: @variant.sku, quantity: 1
            )
          end
        end
      ]
      threads.each(&:join)

      successes = results.values.select(&:success?)
      assert_equal 2, successes.size, results.transform_values { |r| [ r&.success?, r&.error, r&.outcome ] }.inspect

      open_txns = PosTransaction.open_transactions.where(active_pos_session_id: @session.id)
      assert_equal 1, open_txns.count
      assert_equal successes.map { |r| r.pos_transaction.id }.uniq, [ open_txns.first.id ]
      assert_operator open_txns.first.pos_line_items.pending.count, :>=, 2
    end

    private

    def cleanup_operational!
      PosDiscountAllocation.delete_all
      PosDiscount.delete_all
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSessionCashCount.delete_all
      purge_phase7_close_control_rows!
      PosSession.delete_all
      BusinessDay.delete_all
      InventoryLedgerEntry.delete_all
      InventoryAdjustmentLine.delete_all
      InventoryAdjustment.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all
      stores(:main_street).update_column(:next_receipt_sequence, 1)
    end
  end
end
