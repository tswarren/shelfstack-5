# frozen_string_literal: true

require "test_helper"

module Pos
  # Phase 4g-1: mid-completion failures must leave no completed side effects.
  class CompleteTransactionAtomicityTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @store.update_column(:next_receipt_sequence, 1)

      pos_open_inventory(
        store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin
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

    test "reservation conversion failure rolls back without completing or consuming receipt sequence" do
      with_stubbed_singleton_call(Inventory::ConvertReservation, ->(*) { raise Inventory::ConvertReservation::Error, "forced convert failure" }) do
        result = CompleteTransaction.call(
          pos_transaction: @transaction, pos_session: @session, actor: @admin,
          completion_idempotency_key: "atom-convert"
        )
        refute result.success?
        assert_match(/forced convert failure/, result.error)
      end

      assert_open_without_side_effects!
    end

    test "inventory ledger posting failure rolls back without completing" do
      with_stubbed_singleton_call(Inventory::PostLedgerEntry, ->(*) { raise Inventory::PostLedgerEntry::Error, "forced ledger failure" }) do
        result = CompleteTransaction.call(
          pos_transaction: @transaction, pos_session: @session, actor: @admin,
          completion_idempotency_key: "atom-ledger"
        )
        refute result.success?
        assert_match(/forced ledger failure/, result.error)
      end

      assert_open_without_side_effects!
    end

    test "audit failure after receipt allocation rolls back completion and sequence" do
      with_stubbed_singleton_call(
        Administration::RecordAuditEvent,
        ->(*) { raise ActiveRecord::RecordInvalid, AdministrativeAuditEvent.new }
      ) do
        result = CompleteTransaction.call(
          pos_transaction: @transaction, pos_session: @session, actor: @admin,
          completion_idempotency_key: "atom-audit"
        )
        refute result.success?
      end

      assert_open_without_side_effects!
    end

    private

    def assert_open_without_side_effects!
      @transaction.reload
      @line.reload
      assert @transaction.open?
      assert_nil @transaction.receipt_number
      assert_equal 1, @store.reload.next_receipt_sequence
      assert @line.pending?
      assert_equal "pending", @transaction.pos_tenders.sole.status
      reservation = InventoryReservation.find_by(source_type: "pos_line_item", source_id: @line.id)
      assert_equal "active", reservation.status
      assert_nil InventoryLedgerEntry.find_by(posting_key: Inventory::ConvertReservation.posting_key(@line))
    end
  end
end
