# frozen_string_literal: true

require "test_helper"

module StoredValue
  class BalanceAfterEntryTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      IdentifierSequence.ensure_defaults!
      @account = CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
    end

    test "sums ledger through selected entry and ignores later postings" do
      first = PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 2500,
        posting_key: "bal-first", actor: @admin
      ).entry
      second = PostEntry.call(
        account: @account, store: @store, entry_type: "reloaded", amount_cents: 1000,
        posting_key: "bal-second", actor: @admin
      ).entry

      assert_equal 2500, BalanceAfterEntry.call(entry: first).balance_cents
      assert_equal 3500, BalanceAfterEntry.call(entry: second).balance_cents
      assert_equal 3500, @account.reload.current_balance_cents
    end
  end
end
