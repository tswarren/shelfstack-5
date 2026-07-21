# frozen_string_literal: true

require "test_helper"

module StoredValue
  class PostEntryTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @org = @store.organization
      IdentifierSequence.ensure_defaults!
      @account = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin
      ).account
    end

    test "credits and debits update cache and are append-only" do
      credit = PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 2500,
        posting_key: "sv-issue-1", actor: @admin
      )
      refute credit.replayed
      assert_equal 2500, credit.account.current_balance_cents

      debit = PostEntry.call(
        account: @account, store: @store, entry_type: "redeemed", amount_cents: -1000,
        posting_key: "sv-redeem-1", actor: @admin
      )
      assert_equal 1500, debit.account.current_balance_cents

      assert_raises(ActiveRecord::ReadOnlyRecord) { debit.entry.update!(description: "nope") }
    end

    test "insufficient balance is rejected" do
      assert_raises(PostEntry::InsufficientBalanceError) do
        PostEntry.call(
          account: @account, store: @store, entry_type: "redeemed", amount_cents: -1,
          posting_key: "sv-over", actor: @admin
        )
      end
      assert_equal 0, @account.reload.current_balance_cents
    end

    test "idempotent posting key replays" do
      PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 500,
        posting_key: "sv-idem", actor: @admin
      )
      second = PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 500,
        posting_key: "sv-idem", actor: @admin
      )
      assert second.replayed
      assert_equal 500, @account.reload.current_balance_cents
      assert_equal 1, StoredValueEntry.where(posting_key: "sv-idem").count
    end

    test "concurrent debits cannot overspend" do
      PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 1000,
        posting_key: "sv-conc-issue", actor: @admin
      )

      results = {}
      barrier = Concurrent::CyclicBarrier.new(2)

      t1 = Thread.new do
        barrier.wait
        results[:a] = begin
          PostEntry.call(
            account: @account, store: @store, entry_type: "redeemed", amount_cents: -1000,
            posting_key: "sv-conc-a", actor: @admin
          )
          :ok
        rescue PostEntry::Error => e
          e.message
        end
      end
      t2 = Thread.new do
        barrier.wait
        results[:b] = begin
          PostEntry.call(
            account: @account, store: @store, entry_type: "redeemed", amount_cents: -1000,
            posting_key: "sv-conc-b", actor: @admin
          )
          :ok
        rescue PostEntry::Error => e
          e.message
        end
      end
      [ t1, t2 ].each(&:join)

      assert_equal 1, results.values.count(:ok)
      assert results.values.any? { |v| v.is_a?(String) && v.match?(/insufficient/) }
      assert_equal 0, @account.reload.current_balance_cents
    end

    test "reversal requires exact inverse amount and same account" do
      issued = PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 1000,
        posting_key: "sv-rev-issue", actor: @admin
      ).entry

      assert_raises(PostEntry::ReversalError) do
        PostEntry.call(
          account: @account, store: @store, entry_type: "reversal", amount_cents: -500,
          posting_key: "sv-rev-wrong-amt", actor: @admin, reverses_entry: issued
        )
      end

      other = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin
      ).account
      assert_raises(PostEntry::ReversalError) do
        PostEntry.call(
          account: other, store: @store, entry_type: "reversal", amount_cents: -1000,
          posting_key: "sv-rev-wrong-acct", actor: @admin, reverses_entry: issued
        )
      end

      PostEntry.call(
        account: @account, store: @store, entry_type: "reversal", amount_cents: -1000,
        posting_key: "sv-rev-ok", actor: @admin, reverses_entry: issued
      )
      assert_equal 0, @account.reload.current_balance_cents

      assert_raises(PostEntry::ReversalError) do
        PostEntry.call(
          account: @account, store: @store, entry_type: "reversal", amount_cents: -1000,
          posting_key: "sv-rev-double", actor: @admin, reverses_entry: issued
        )
      end
    end
  end
end
