# frozen_string_literal: true

require "test_helper"

module Pos
  # Gate 11C baseline tender contracts. Posting services are preserved; this
  # matrix documents and verifies the shell-to-posting boundary (Slice 8 cash
  # checkpoint before broader tender polish).
  class Phase11cTenderContractMatrixTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @card = tender_types(:card_standalone)
      pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
    end

    test "slice 8 cash completion checkpoint is atomic and idempotent" do
      txn, _line, net = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "11c-cash-checkpoint"
      )
      assert txn.completed?
      assert txn.receipt_number.present?

      replay = CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "11c-cash-checkpoint"
      )
      assert replay.success?
      assert replay.replayed
      assert_equal 1, PosTransaction.where(id: txn.id, status: "completed").count

      presentation = WorkspacePresentation.for(pos_transaction: txn.reload)
      assert_equal "receipt", presentation.state
      assert_equal net, txn.net_total_cents
    end

    test "positive balance forces tender when unresolved cash exists" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net / 2, actor: @admin
      )

      workspace = WorkspacePresentation.for(
        pos_transaction: txn.reload, net_total_cents: net, balance_due_cents: net - (net / 2)
      )
      assert_equal "tender", workspace.state
      assert workspace.forced_tender
      refute txn.editable?
    end

    test "void_required restores recovery and blocks commercial edit" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddOpenRingLine.call(
        pos_transaction: txn, department: departments(:books_new), unit_price_cents: 1000, actor: @admin
      )
      mismatch = AddCardTender.call(
        pos_transaction: txn, tender_type: @card, amount_cents: 1500,
        authorization_code: "11C-VOID", actor: @admin
      )
      assert mismatch.requires_void_confirmation?
      assert txn.reload.void_required_tenders?
      refute txn.editable?

      workspace = WorkspacePresentation.for(pos_transaction: txn, presentation_param: "tender")
      assert_equal "recovery", workspace.state
    end

    test "successful completion followed by receipt presentation cannot reverse completion" do
      txn, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "11c-receipt-immutable"
      )
      status_before = txn.reload.status
      receipt_before = txn.receipt_number

      workspace = WorkspacePresentation.for(pos_transaction: txn)
      assert_equal "receipt", workspace.state
      assert_equal status_before, txn.reload.status
      assert_equal receipt_before, txn.receipt_number
      refute AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: 100, actor: @admin
      ).success?
    end
  end
end
