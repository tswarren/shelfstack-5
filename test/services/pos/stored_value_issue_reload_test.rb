# frozen_string_literal: true

require "test_helper"

module Pos
  class StoredValueIssueReloadTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @cash = tender_types(:cash)
      IdentifierSequence.ensure_defaults!

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
    end

    test "issue line increases amount due, skips tax, and posts liability on complete" do
      line_result = AddStoredValueLine.call(
        pos_transaction: @transaction, account: @account, operation: "issue",
        amount_cents: 2500, actor: @admin
      )
      assert line_result.success?, line_result.error

      totals = RecalculateTransaction.call(pos_transaction: @transaction)
      assert_equal 0, totals.subtotal_cents
      assert_equal 0, totals.tax_total_cents
      assert_equal 2500, totals.net_total_cents

      AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash,
        amount_tendered_cents: 2500, actor: @admin
      )
      completed = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sv-issue-1"
      )
      assert completed.success?, completed.error
      assert_equal 2500, @account.reload.current_balance_cents
      assert StoredValueEntry.exists?(
        stored_value_account_id: @account.id, entry_type: "issued", amount_cents: 2500
      )
    end

    test "reload posts reloaded entry" do
      StoredValue::PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 1000,
        posting_key: "seed-issue", actor: @admin
      )

      AddStoredValueLine.call(
        pos_transaction: @transaction, account: @account, operation: "reload",
        amount_cents: 500, actor: @admin
      )
      AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash,
        amount_tendered_cents: 500, actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sv-reload-1"
      ).success?

      assert_equal 1500, @account.reload.current_balance_cents
      assert StoredValueEntry.exists?(entry_type: "reloaded", amount_cents: 500)
    end
  end
end
