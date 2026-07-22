# frozen_string_literal: true

require "test_helper"

module Pos
  class PostVoidStoredValueTest < ActiveSupport::TestCase
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

      @account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
    end

    test "post-void reverses gift-card issue liability" do
      transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddStoredValueLine.call(
        pos_transaction: transaction, account: @account, operation: "issue",
        amount_cents: 2000, actor: @admin
      )
      AddCashTender.call(
        pos_transaction: transaction, tender_type: @cash,
        amount_tendered_cents: 2000, actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sv-sale"
      ).success?
      assert_equal 2000, @account.reload.current_balance_cents

      result = pos_post_void!(
        original: transaction.reload, actor: @admin, reason: "customer changed mind",
        pos_session: @session, key: "pv-sv-1"
      )
      assert result.success?, result.error
      assert_equal 0, @account.reload.current_balance_cents
      assert StoredValueEntry.exists?(entry_type: "reversal", amount_cents: -2000)
    end

    test "later redemption blocks post-void of issue" do
      transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddStoredValueLine.call(
        pos_transaction: transaction, account: @account, operation: "issue",
        amount_cents: 2000, actor: @admin
      )
      AddCashTender.call(
        pos_transaction: transaction, tender_type: @cash,
        amount_tendered_cents: 2000, actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sv-sale-2"
      ).success?

      StoredValue::PostEntry.call(
        account: @account, store: @store, entry_type: "redeemed", amount_cents: -500,
        posting_key: "later-redeem", actor: @admin
      )

      eligibility = EvaluatePostVoidEligibility.call(original_transaction: transaction.reload)
      refute eligibility.eligible?
      assert eligibility.blockers.any? { |b| b.match?(/later redeemed/) }
    end
  end
end
