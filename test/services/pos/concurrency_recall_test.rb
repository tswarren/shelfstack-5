# frozen_string_literal: true

require "test_helper"

module Pos
  class ConcurrencyRecallTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      cleanup!
      @store = stores(:main_street)
      @admin = users(:admin)
      @device_a = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @device_b = PosDevice.find_or_create_by!(store: @store, code: "REG2") do |device|
        device.name = "Register 2"
        device.device_type = "register"
        device.active = true
      end
      @variant = product_variants(:sample_book_standard)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session_a = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device_a, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @session_b = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device_b,
        cashier: @admin, actor: @admin
      ).pos_session

      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      @suspended = SuspendTransaction.call(pos_transaction: transaction, actor: @admin).pos_transaction
    end

    teardown { cleanup! }

    test "concurrent recall of the same suspended transaction has exactly one winner" do
      results = []
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results << RecallTransaction.call(pos_transaction: @suspended, pos_session: @session_a, actor: @admin)
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results << RecallTransaction.call(pos_transaction: @suspended, pos_session: @session_b, actor: @admin)
          end
        end
      ]
      threads.each(&:join)

      successes = results.select(&:success?)
      failures = results.reject(&:success?)

      assert_equal 1, successes.size, results.map(&:error).inspect
      assert_equal 1, failures.size

      @suspended.reload
      assert @suspended.open?
      assert_includes [ @session_a.id, @session_b.id ], @suspended.active_pos_session_id
    end

    test "recall fails when session already controls an open transaction" do
      open_txn = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction

      result = RecallTransaction.call(pos_transaction: @suspended, pos_session: @session_a, actor: @admin)
      refute result.success?
      assert_match(/Suspend or complete/, result.error)

      @suspended.reload
      assert @suspended.suspended?
      assert_equal 1, PosTransaction.open_transactions.where(active_pos_session_id: @session_a.id).count
      assert_equal open_txn.id, PosTransaction.open_transactions.find_by(active_pos_session_id: @session_a.id).id
    end

    test "concurrent double recall onto empty session has exactly one winner" do
      other = OpenTransaction.call(pos_session: @session_b, actor: @admin).pos_transaction
      suspended_b = SuspendTransaction.call(pos_transaction: other, actor: @admin).pos_transaction

      results = {}
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:a] = RecallTransaction.call(
              pos_transaction: @suspended, pos_session: @session_a, actor: @admin
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:b] = RecallTransaction.call(
              pos_transaction: suspended_b, pos_session: @session_a, actor: @admin
            )
          end
        end
      ]
      threads.each(&:join)

      successes = results.values.select(&:success?)
      failures = results.values.reject(&:success?)
      assert_equal 1, successes.size, results.transform_values(&:error).inspect
      assert_equal 1, failures.size
      assert_match(/Suspend or complete/, failures.first.error)
      assert_equal 1, PosTransaction.open_transactions.where(active_pos_session_id: @session_a.id).count
    end

    test "concurrent recall versus scan-to-start leaves one open transaction" do
      pos_open_inventory(store: @store, variant: @variant, quantity: 5, unit_cost_cents: 500, actor: @admin)

      results = {}
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:recall] = RecallTransaction.call(
              pos_transaction: @suspended, pos_session: @session_a, actor: @admin
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:scan] = ScanToStart.call(
              pos_session: @session_a, actor: @admin, query: @variant.sku, quantity: 1
            )
          end
        end
      ]
      threads.each(&:join)

      open_txns = PosTransaction.open_transactions.where(active_pos_session_id: @session_a.id)
      assert_equal 1, open_txns.count, results.transform_values { |r| [ r&.success?, r&.error ] }.inspect

      # Exactly one of recall or scan-to-start should own the session's open txn.
      if results[:recall].success?
        assert_equal @suspended.id, open_txns.first.id
        refute results[:scan].success? if open_txns.first.pos_line_items.pending.none?
      else
        assert results[:scan].success?, results[:scan]&.error
        assert_equal open_txns.first.id, results[:scan].pos_transaction.id
        @suspended.reload
        assert @suspended.suspended?
      end
    end

    private

    def cleanup!
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
    end
  end
end
