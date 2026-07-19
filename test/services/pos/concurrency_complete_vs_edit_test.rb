# frozen_string_literal: true

require "test_helper"

module Pos
  # Recall requires a Transaction to already be `suspended`, and Suspend itself
  # is blocked while an unresolved Tender exists (see SuspendTransaction /
  # Pos::CompleteTransactionTest), so an `open` Transaction with a settling
  # Tender can never be concurrently `suspended`/recalled — Complete vs Recall
  # cannot race on the same state. Complete vs an ordinary commercial edit
  # (RemoveLine) on the same still-`open` Transaction can, and is the
  # meaningful case: both lock the same pending Line row, so exactly one wins.
  class ConcurrencyCompleteVsEditTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all
      InventoryLedgerEntry.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all

      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)

      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: @variant, position: 0, quantity_delta: 5,
        input_unit_cost_cents: 500, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item

      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin)
    end

    teardown do
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all
      InventoryLedgerEntry.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all
      # Not transactional (see above); a successful race leaves the shared store
      # fixture's receipt sequence incremented, so restore it for later tests.
      @store.update_column(:next_receipt_sequence, 1)
    end

    test "concurrent completion vs removing the same line has exactly one winner and no corrupted state" do
      results = {}
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:complete] = CompleteTransaction.call(
              pos_transaction: @transaction, pos_session: @session, actor: @admin,
              completion_idempotency_key: "race-1"
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:remove] = RemoveLine.call(pos_line_item: @line, actor: @admin, reason: "race")
          end
        end
      ]
      threads.each(&:join)

      successes = results.values.select(&:success?)
      assert_equal 1, successes.size, results.transform_values(&:error).inspect

      @transaction.reload
      @line.reload

      if results[:complete].success?
        assert @transaction.completed?
        assert @line.completed?
        refute results[:remove].success?
        assert_match(/not pending|not open/, results[:remove].error)
      else
        assert results[:remove].success?
        assert @transaction.open?
        assert @line.removed?
        refute results[:complete].success?
      end
    end
  end
end
