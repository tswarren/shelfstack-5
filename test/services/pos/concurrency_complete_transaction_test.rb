# frozen_string_literal: true

require "test_helper"

module Pos
  # Phase 4g-1: two completion attempts against one open transaction.
  class ConcurrencyCompleteTransactionTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      cleanup_operational!
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @store.update_column(:next_receipt_sequence, 1)

      pos_open_inventory(
        store: @store, variant: @variant, quantity: 3, unit_cost_cents: 500, actor: @admin
      )
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @line = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin
      ).pos_line_item
      @net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: @net, actor: @admin
      )
    end

    teardown { cleanup_operational! }

    test "concurrent completions produce one success, one receipt, one sequence bump, one ledger" do
      results = {}
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:a] = CompleteTransaction.call(
              pos_transaction: @transaction, pos_session: @session, actor: @admin,
              completion_idempotency_key: "dual-a"
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:b] = CompleteTransaction.call(
              pos_transaction: @transaction, pos_session: @session, actor: @admin,
              completion_idempotency_key: "dual-b"
            )
          end
        end
      ]
      threads.each(&:join)

      successes = results.values.select(&:success?)
      assert_equal 1, successes.size, results.transform_values { |r| [ r&.success?, r&.error, r&.replayed ] }.inspect

      @transaction.reload
      assert @transaction.completed?
      assert_equal "001-000001", @transaction.receipt_number
      assert_equal 1, @transaction.receipt_sequence
      assert_equal 2, @store.reload.next_receipt_sequence
      assert_equal 1, InventoryLedgerEntry.where(
        posting_key: Inventory::ConvertReservation.posting_key(@line.reload)
      ).count
      assert_equal "converted", InventoryReservation.find_by!(
        source_type: "pos_line_item", source_id: @line.id
      ).status
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
