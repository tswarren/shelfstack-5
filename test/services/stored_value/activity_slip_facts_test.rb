# frozen_string_literal: true

require "test_helper"

module StoredValue
  class ActivitySlipFactsTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      IdentifierSequence.ensure_defaults!
      @account = CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      @entry = PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 2500,
        posting_key: "slip-facts-issued", actor: @admin
      ).entry
    end

    test "masks account number and uses positive directional amount with historical balance" do
      facts = ActivitySlipFacts.call(entry: @entry, store: @store, reprint: false)
      assert_equal "GIFT CARD ISSUED", facts.title
      assert_equal "Issuance amount", facts.amount_label
      assert_equal 2500, facts.amount_cents
      assert_equal 2500, facts.balance_after_cents
      assert_includes facts.masked_account_number, @account.account_number[-4, 4]
      refute_includes facts.masked_account_number, @account.account_number
      assert_equal false, facts.reprint
    end

    test "reprint retains historical balance after later reload" do
      PostEntry.call(
        account: @account, store: @store, entry_type: "reloaded", amount_cents: 500,
        posting_key: "slip-facts-reload", actor: @admin
      )
      facts = ActivitySlipFacts.call(entry: @entry, store: @store, reprint: true)
      assert_equal 2500, facts.balance_after_cents
      assert facts.reprint
      assert facts.reprint_at.present?
    end

    test "rejects out-of-scope entry types" do
      redeemed = PostEntry.call(
        account: @account, store: @store, entry_type: "redeemed", amount_cents: -500,
        posting_key: "slip-facts-redeem", actor: @admin
      ).entry
      assert_raises(ActivitySlipFacts::Error) do
        ActivitySlipFacts.call(entry: redeemed, store: @store)
      end
    end
  end
end
