# frozen_string_literal: true

require "test_helper"

module Pos
  class StageAndAttachCustomerTest < ActiveSupport::TestCase
    setup do
      IdentifierSequence.ensure_defaults!
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @customer = customers(:jordan_lee)
      @variant = product_variants(:upc_product_standard)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      @cash = @store.organization.tender_types.find_by!(tender_category: "cash")
    end

    test "only staging user consumes staged customer on open transaction" do
      stage = StageCustomer.call(pos_session: @session, customer: @customer, actor: @admin)
      assert stage.success?, stage.error

      # Another actor opening a transaction does not consume the stage.
      other = OpenTransaction.call(pos_session: @session, actor: @clerk)
      assert other.success?, other.error
      assert_nil other.pos_transaction.customer_id
      @session.reload
      assert_equal @customer.id, @session.staged_customer_id

      # Staging owner opening a transaction consumes and clears.
      owned = OpenTransaction.call(pos_session: @session, actor: @admin)
      assert owned.success?, owned.error
      assert_equal @customer.id, owned.pos_transaction.customer_id
      @session.reload
      assert_nil @session.staged_customer_id
    end

    test "attach is blocked when tenders lock commercial editing" do
      pos_open_inventory(store: @store, variant: @variant, quantity: 5, unit_cost_cents: 500, actor: @admin)
      open = OpenTransaction.call(pos_session: @session, actor: @admin)
      txn = open.pos_transaction
      add = AddLine.call(pos_transaction: txn, product_variant: @variant, actor: @admin, quantity: 1)
      assert add.success?, add.error

      tender = AddCashTender.call(
        pos_transaction: txn,
        tender_type: @cash,
        actor: @admin,
        amount_tendered_cents: 100
      )
      assert tender.success?, tender.error
      txn.reload
      assert txn.unresolved_tenders?

      result = AttachCustomer.call(pos_transaction: txn, customer: @customer, actor: @admin)
      assert_not result.success?
      assert_match(/not editable/i, result.error)
    end

    test "inactive customer cannot be staged" do
      result = StageCustomer.call(
        pos_session: @session,
        customer: customers(:inactive_patron),
        actor: @admin
      )
      assert_not result.success?
      assert_match(/inactive/i, result.error)
    end

    test "consume preserves stage when transaction already has a different customer" do
      other = customers(:riverside_school)
      open = OpenTransaction.call(pos_session: @session, actor: @admin)
      txn = open.pos_transaction
      AttachCustomer.call(pos_transaction: txn, customer: @customer, actor: @admin)

      stage = StageCustomer.call(pos_session: @session, customer: other, actor: @admin)
      assert stage.success?, stage.error

      result = ConsumeStagedCustomer.call(
        pos_session: @session.reload,
        pos_transaction: txn.reload,
        actor: @admin
      )

      assert result.success?
      assert result.conflict?
      assert_not result.consumed
      assert_equal @customer.id, txn.reload.customer_id
      assert_equal other.id, @session.reload.staged_customer_id
    end

    test "consume clears stage when transaction already has the same customer" do
      open = OpenTransaction.call(pos_session: @session, actor: @admin)
      txn = open.pos_transaction
      # OpenTransaction may already have consumed a stage; ensure attached then re-stage same.
      AttachCustomer.call(pos_transaction: txn, customer: @customer, actor: @admin) if txn.customer_id.blank?
      StageCustomer.call(pos_session: @session, customer: @customer, actor: @admin)

      result = ConsumeStagedCustomer.call(
        pos_session: @session.reload,
        pos_transaction: txn.reload,
        actor: @admin
      )

      assert result.success?
      assert_not result.conflict?
      assert result.consumed
      assert_equal @customer.id, txn.reload.customer_id
      assert_nil @session.reload.staged_customer_id
    end
  end
end
