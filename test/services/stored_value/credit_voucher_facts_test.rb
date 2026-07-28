# frozen_string_literal: true

require "test_helper"

module StoredValue
  class CreditVoucherFactsTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      IdentifierSequence.ensure_defaults!
      @account = CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 1800,
        posting_key: "voucher-facts-issued", actor: @admin
      )
    end

    test "exposes full account number barcode and current balance" do
      facts = CreditVoucherFacts.call(account: @account.reload, store: @store, reprint: false)
      assert_equal @account.account_number, facts.account_number
      assert_equal 1800, facts.current_balance_cents
      assert_equal @account.account_number, facts.barcode.payload
      assert_nil facts.barcode.error
      assert_includes facts.barcode.svg.to_s, "<svg"
      assert_equal false, facts.reprint
    end

    test "reprint reflects current balance after intervening entry" do
      before = CreditVoucherFacts.call(account: @account.reload, store: @store, reprint: true)
      assert_equal 1800, before.current_balance_cents

      PostEntry.call(
        account: @account, store: @store, entry_type: "reloaded", amount_cents: 200,
        posting_key: "voucher-facts-reload", actor: @admin
      )
      after = CreditVoucherFacts.call(account: @account.reload, store: @store, reprint: true)
      assert_equal 2000, after.current_balance_cents
      assert after.reprint
    end

    test "suspended accounts cannot produce a voucher" do
      @account.reload.update!(status: "suspended")
      error = assert_raises(CreditVoucherFacts::SuspendedError) do
        CreditVoucherFacts.call(account: @account, store: @store)
      end
      assert_match(/suspended/i, error.message)
    end
  end
end
