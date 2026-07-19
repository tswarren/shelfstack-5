# frozen_string_literal: true

require "test_helper"

module Pos
  class CompleteTransactionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @none_variant = product_variants(:gift_wrap_service_standard)
      @department = departments(:books_new)
      @cash = tender_types(:cash)
      @card = tender_types(:card_standalone)

      open_inventory(@variant, quantity: 2, unit_cost_cents: 500)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "successful completion posts inventory, snapshots cost, and assigns a receipt number" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
      none_line = AddLine.call(pos_transaction: @transaction, product_variant: @none_variant, quantity: 1, actor: @admin).pos_line_item

      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      tender = AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin
      ).pos_tender

      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "key-1"
      )

      assert result.success?, result.error
      refute result.replayed

      @transaction.reload
      assert @transaction.completed?
      assert_equal @admin, @transaction.completed_by_user
      assert_equal @session, @transaction.completed_pos_session
      assert @transaction.receipt_number.present?
      assert_equal "001-000001", @transaction.receipt_number
      assert_equal 1, @transaction.receipt_sequence
      assert_equal net_total, @transaction.net_total_cents

      line.reload
      assert line.completed?
      assert line.completed_at.present?
      assert_equal 500, line.cost_unit_cost_cents
      assert_equal 1000, line.cost_extended_cents
      assert_equal "moving_average", line.cost_method_snapshot
      assert_equal "actual", line.cost_quality_snapshot

      none_line.reload
      assert none_line.completed?
      assert_nil none_line.cost_unit_cost_cents

      tender.reload
      assert tender.completed?
      assert tender.completed_at.present?

      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal 0, balance.on_hand
      assert_equal 0, balance.reserved

      ledger_entry = InventoryLedgerEntry.find_by(posting_key: Inventory::ConvertReservation.posting_key(line))
      assert ledger_entry
      assert_equal "sale", ledger_entry.movement_type
      assert_equal(-2, ledger_entry.quantity_delta)

      reservation = InventoryReservation.find_by(source_type: "pos_line_item", source_id: line.id)
      assert_equal "converted", reservation.status

      @store.reload
      assert_equal 2, @store.next_receipt_sequence
    end

    test "repeating completion with the same idempotency key replays the prior success" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin)

      first = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "double-submit"
      )
      assert first.success?

      second = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "double-submit"
      )
      assert second.success?
      assert second.replayed
      assert_equal first.pos_transaction.receipt_number, second.pos_transaction.receipt_number

      @store.reload
      assert_equal 2, @store.next_receipt_sequence
      assert_equal 1, InventoryLedgerEntry.where(posting_key: Inventory::ConvertReservation.posting_key(line)).count
    end

    test "completing an already-completed transaction under a different key fails" do
      AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin)
      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin)

      assert CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "key-a"
      ).success?

      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "key-b"
      )
      refute result.success?
      assert_match(/already completed/, result.error)
    end

    test "failed completion (tenders do not settle) leaves no partial inventory or tender effects" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
      tender = AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 1, actor: @admin
      ).pos_tender

      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "short-tender"
      )

      refute result.success?
      assert_match(/do not settle/, result.error)

      @transaction.reload
      assert @transaction.open?
      assert_nil @transaction.receipt_number

      line.reload
      assert line.pending?
      assert_nil line.cost_unit_cost_cents

      tender.reload
      assert_equal "pending", tender.status

      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal 2, balance.on_hand
      assert_equal 2, balance.reserved

      reservation = InventoryReservation.find_by(source_type: "pos_line_item", source_id: line.id)
      assert_equal "active", reservation.status

      @store.reload
      assert_equal 1, @store.next_receipt_sequence
    end

    test "sale beyond on-hand posts with a provisional last-known cost and a negative-available warning" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item

      # Shrinkage discovered after reservation, before completion: on_hand drops to
      # zero while the Reservation still holds 2 (OD-014 interim: sale may still
      # complete, carrying the last documented positive rate provisionally).
      shortage = InventoryAdjustment.create!(
        store: @store, kind: "quantity_only", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:quantity_shortage), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: shortage, product_variant: @variant, position: 0, quantity_delta: -2
      )
      assert Inventory::PostAdjustment.call(adjustment: shortage, actor: @admin, store: @store).success?

      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin)

      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "negative-sale"
      )

      assert result.success?, result.error
      assert_includes result.warnings, "available quantity is negative after sale"

      line.reload
      assert_equal 500, line.cost_unit_cost_cents
      assert_equal "last_known", line.cost_method_snapshot
      assert_equal "actual", line.cost_quality_snapshot

      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal(-2, balance.on_hand)
      assert_equal 0, balance.reserved
      assert_equal 0, balance.inventory_value_cents
      assert_nil balance.moving_average_cost_cents
    end

    test "standalone card tender remains authorized and visible after a failed completion" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents

      card_tender = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net_total,
        authorization_code: "AUTH123", terminal_reference: "TERM-1", actor: @admin
      ).pos_tender
      assert_equal "authorized", card_tender.status

      # Force completion to fail after the card was externally authorized by
      # making the department non-postable (ADR-0009's external-terminal
      # limitation: a failed internal completion must not revert the terminal
      # authorization already confirmed by the cashier).
      @department.update_columns(postable: false)

      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "card-then-fail"
      )
      refute result.success?

      @transaction.reload
      assert @transaction.open?

      card_tender.reload
      assert_equal "authorized", card_tender.status
      assert_equal "AUTH123", card_tender.authorization_code

      line.reload
      assert line.pending?
    ensure
      @department.update_columns(postable: true)
    end

    test "commercial edits are blocked while a tender is pending, and clearing it unlocks editing" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
      tender = AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 100, actor: @admin
      ).pos_tender

      refute @transaction.reload.editable?
      denied = RemoveLine.call(pos_line_item: line, actor: @admin)
      refute denied.success?
      assert_match(/not open for editing/, denied.error)

      removed = RemoveTender.call(pos_tender: tender, actor: @admin, reason: "customer changed mind")
      assert removed.success?
      assert_equal "removed", removed.pos_tender.status

      assert @transaction.reload.editable?
      allowed = RemoveLine.call(pos_line_item: line, actor: @admin)
      assert allowed.success?
    end

    test "session close is blocked while a transaction it controls has unresolved tenders" do
      AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin)
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 100, actor: @admin)

      # Suspension itself is blocked by unresolved Tenders (domain: "Suspension
      # ... requires no unresolved Tender activity"), so the Transaction still
      # controls the Session as an open Transaction.
      suspend_result = SuspendTransaction.call(pos_transaction: @transaction, actor: @admin)
      refute suspend_result.success?
      @transaction.reload
      assert @transaction.open?

      result = CloseSession.call(pos_session: @session, actor: @admin)
      refute result.success?
      assert_match(/open transaction/, result.error)
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
        input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
    end
  end
end
