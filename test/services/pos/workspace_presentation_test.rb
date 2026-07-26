# frozen_string_literal: true

require "test_helper"

module Pos
  class WorkspacePresentationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @card = tender_types(:card_standalone)
      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "ready when no transaction" do
      result = WorkspacePresentation.for(pos_transaction: nil, open_session: @session)
      assert_equal "ready", result.state
      assert_equal "Ready", result.label
      assert_includes WorkspacePresentation::PRESENTATIONS, result.state
    end

    test "ready when transaction is cancelled" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert CancelTransaction.call(pos_transaction: txn, actor: @admin, reason: "test cancel").success?

      result = WorkspacePresentation.for(pos_transaction: txn.reload)
      assert_equal "ready", result.state
    end

    test "transaction for open editable sale" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, actor: @admin, quantity: 1)

      result = WorkspacePresentation.for(pos_transaction: txn.reload, net_total_cents: 1000)
      assert_equal "transaction", result.state
      assert_equal "Transaction", result.label
      refute result.forced_tender
    end

    test "transaction for suspended sale" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, actor: @admin, quantity: 1)
      assert SuspendTransaction.call(pos_transaction: txn, actor: @admin).success?

      result = WorkspacePresentation.for(pos_transaction: txn.reload)
      assert_equal "transaction", result.state
    end

    test "tender when presentation param requests tender" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, actor: @admin, quantity: 1)

      result = WorkspacePresentation.for(
        pos_transaction: txn.reload,
        presentation_param: "tender",
        net_total_cents: 1000,
        balance_due_cents: 1000
      )
      assert_equal "tender", result.state
      refute result.forced_tender
    end

    test "forces tender when unresolved tenders exist" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, actor: @admin, quantity: 1)
      AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: 100, actor: @admin
      )

      result = WorkspacePresentation.for(
        pos_transaction: txn.reload,
        presentation_param: nil,
        net_total_cents: 1000,
        balance_due_cents: 900
      )
      assert_equal "tender", result.state
      assert result.forced_tender
    end

    test "recovery when void_required tenders exist" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddOpenRingLine.call(
        pos_transaction: txn, department: departments(:books_new), unit_price_cents: 1000, actor: @admin
      )
      card = AddCardTender.call(
        pos_transaction: txn,
        tender_type: @card,
        amount_cents: 1500,
        authorization_code: "AUTH-VOID",
        actor: @admin
      )
      refute card.success?
      assert card.requires_void_confirmation?
      assert txn.reload.void_required_tenders?

      result = WorkspacePresentation.for(
        pos_transaction: txn,
        presentation_param: "tender",
        net_total_cents: 1000,
        balance_due_cents: 1000
      )
      assert_equal "recovery", result.state
      assert_equal "Recovery", result.label
    end

    test "receipt when transaction is completed" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddOpenRingLine.call(
        pos_transaction: txn, department: departments(:books_new), unit_price_cents: 1000, actor: @admin
      )
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      assert AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin
      ).success?
      complete = CompleteTransaction.call(
        pos_transaction: txn,
        pos_session: @session,
        actor: @admin,
        completion_idempotency_key: SecureRandom.uuid
      )
      assert complete.success?, complete.error

      result = WorkspacePresentation.for(pos_transaction: txn.reload)
      assert_equal "receipt", result.state
      assert_equal "Receipt", result.label
    end

    test "derivation is pure with respect to presentation_param changes" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, actor: @admin, quantity: 1)
      before = txn.reload.attributes.slice("status", "updated_at", "net_total_cents")

      WorkspacePresentation.for(pos_transaction: txn, presentation_param: "tender")
      WorkspacePresentation.for(pos_transaction: txn, presentation_param: nil)

      after = txn.reload.attributes.slice("status", "updated_at", "net_total_cents")
      assert_equal before, after
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
        input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
    end
  end
end
