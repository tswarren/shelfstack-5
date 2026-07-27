# frozen_string_literal: true

require "test_helper"

module Pos
  class StartStoredValueTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @customer = customers(:jordan_lee)
      @other_customer = customers(:riverside_school)
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
      audit_count = AdministrativeAuditEvent.where(action: "stored_value_account.created").count

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
      assert_equal audit_count, AdministrativeAuditEvent.where(action: "stored_value_account.created").count
    end

    test "create-account plus failed OpenTransaction leaves no account transaction audit or line" do
      account_count = StoredValueAccount.count
      txn_count = PosTransaction.count
      audit_count = AdministrativeAuditEvent.where(action: "stored_value_account.created").count
      line_count = PosLineItem.where(line_kind: "stored_value").count

      with_stubbed_singleton_call(
        OpenTransaction,
        ->(**) { OpenTransaction::Result.new(pos_transaction: nil, success?: false, error: "session must be open") }
      ) do
        result = StartStoredValue.call(
          pos_session: @session,
          actor: @admin,
          create_account: true,
          organization: @store.organization,
          store: @store,
          operation: "issue",
          amount_cents: 1500
        )

        refute result.success?
        assert_match(/session must be open/i, result.error)
      end

      assert_equal account_count, StoredValueAccount.count
      assert_equal txn_count, PosTransaction.count
      assert_equal audit_count, AdministrativeAuditEvent.where(action: "stored_value_account.created").count
      assert_equal line_count, PosLineItem.where(line_kind: "stored_value").count
    end

    test "create-account plus staged customer conflict leaves no account audit or line" do
      open = OpenTransaction.call(pos_session: @session, actor: @admin)
      txn = open.pos_transaction
      assert AttachCustomer.call(pos_transaction: txn, customer: @customer, actor: @admin).success?
      assert StageCustomer.call(pos_session: @session, customer: @other_customer, actor: @admin).success?

      account_count = StoredValueAccount.count
      txn_count = PosTransaction.count
      audit_count = AdministrativeAuditEvent.where(action: "stored_value_account.created").count
      line_count = PosLineItem.where(line_kind: "stored_value").count

      result = StartStoredValue.call(
        pos_session: @session.reload,
        actor: @admin,
        create_account: true,
        organization: @store.organization,
        store: @store,
        operation: "issue",
        amount_cents: 1500
      )

      refute result.success?
      assert_match(/different customer/i, result.error)
      assert_equal account_count, StoredValueAccount.count
      assert_equal txn_count, PosTransaction.count
      assert_equal audit_count, AdministrativeAuditEvent.where(action: "stored_value_account.created").count
      assert_equal line_count, PosLineItem.where(line_kind: "stored_value").count
      assert_equal @customer.id, txn.reload.customer_id
      assert_equal @other_customer.id, @session.reload.staged_customer_id
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
      account = result.pos_line_item.stored_value_account
      assert AdministrativeAuditEvent.exists?(
        action: "stored_value_account.created",
        subject_type: "StoredValueAccount",
        subject_id: account.id
      )
    end
  end
end
