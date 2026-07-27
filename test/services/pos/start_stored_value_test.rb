# frozen_string_literal: true

require "test_helper"

module Pos
  class StartStoredValueTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      IdentifierSequence.ensure_defaults!

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "failed create-account start does not leave orphan account or transaction" do
      account_count = StoredValueAccount.count
      txn_count = PosTransaction.count

      result = StartStoredValue.call(
        pos_session: @session,
        actor: @admin,
        create_account: true,
        organization: @store.organization,
        store: @store,
        operation: "issue",
        amount_cents: 0
      )

      refute result.success?
      assert_equal account_count, StoredValueAccount.count
      assert_equal txn_count, PosTransaction.count
    end

    test "successful create-account start opens transaction and adds line atomically" do
      account_count = StoredValueAccount.count

      result = StartStoredValue.call(
        pos_session: @session,
        actor: @admin,
        create_account: true,
        organization: @store.organization,
        store: @store,
        operation: "issue",
        amount_cents: 1500
      )

      assert result.success?, result.error
      assert_equal account_count + 1, StoredValueAccount.count
      assert result.pos_transaction.open?
      assert_equal 1, result.pos_transaction.pos_line_items.pending.where(line_kind: "stored_value").count
    end
  end
end
