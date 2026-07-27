# frozen_string_literal: true

require "test_helper"

module Pos
  # Gate 11C tender acceptance bar. Keeps one automated contract per exit
  # combination (cash / card / stored-value / refund / split) plus shell safety
  # checkpoints. Broader edge coverage remains in dedicated service tests.
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
      @sv_tender = tender_types(:stored_value)
      IdentifierSequence.ensure_defaults!
      pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
    end

    test "cash completion is atomic and idempotent" do
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

    test "standalone card completion settles and transitions to receipt" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents

      card = AddCardTender.call(
        pos_transaction: txn, tender_type: @card, amount_cents: net,
        authorization_code: "11C-CARD", actor: @admin
      )
      assert card.success?, card.error

      complete = CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "11c-card"
      )
      assert complete.success?, complete.error
      assert_equal "receipt", WorkspacePresentation.for(pos_transaction: txn.reload).state
      assert_equal "card", txn.pos_tenders.where(status: "completed").first.tender_type.tender_category
    end

    test "stored-value redemption settles and posts ledger on complete" do
      account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      StoredValue::PostEntry.call(
        account: account, store: @store, entry_type: "issued", amount_cents: 5000,
        posting_key: "11c-sv-seed", actor: @admin
      )

      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents

      tender = AddStoredValueTender.call(
        pos_transaction: txn, tender_type: @sv_tender, account: account,
        amount_cents: net, actor: @admin
      )
      assert tender.success?, tender.error

      complete = CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "11c-sv-redeem"
      )
      assert complete.success?, complete.error
      assert_equal 5000 - net, account.reload.current_balance_cents
      assert_equal "receipt", WorkspacePresentation.for(pos_transaction: txn.reload).state
    end

    test "cash plus card split tender completes atomically" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      cash_part = [ net / 2, 1 ].max
      card_part = net - cash_part

      cash = AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: cash_part, actor: @admin
      )
      assert cash.success?, cash.error
      card = AddCardTender.call(
        pos_transaction: txn, tender_type: @card, amount_cents: card_part,
        authorization_code: "11C-SPLIT", actor: @admin
      )
      assert card.success?, card.error

      complete = CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "11c-split"
      )
      assert complete.success?, complete.error
      assert_equal 2, txn.reload.pos_tenders.where(status: "completed").count
      assert_equal "receipt", WorkspacePresentation.for(pos_transaction: txn).state
    end

    test "linked return cash refund completes and keeps receipt immutable" do
      sale, sale_line, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "11c-sale-for-refund"
      )

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      returned = AddLinkedReturnLine.call(
        pos_transaction: ret,
        original_pos_line_item: sale_line,
        quantity: 1,
        return_reason: return_reasons(:unwanted),
        return_disposition: "return_to_stock",
        actor: @admin
      )
      assert returned.success?, returned.error

      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      refund = pos_add_cash_refund(
        pos_transaction: ret, amount_cents: refund_due, actor: @admin
      )
      assert refund.success?, refund.error

      complete = CompleteTransaction.call(
        pos_transaction: ret, pos_session: @session, actor: @admin,
        completion_idempotency_key: "11c-cash-refund"
      )
      assert complete.success?, complete.error
      assert ret.reload.completed?
      assert_equal "receipt", WorkspacePresentation.for(pos_transaction: ret).state
      refute_equal sale.receipt_number, ret.receipt_number
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
