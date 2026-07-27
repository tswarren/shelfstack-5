# frozen_string_literal: true

require "test_helper"

module Pos
  # Non-system Recovery contract: mismatch → void_required → confirm → voided → usable again.
  class RecoveryVoidRequiredIntegrationTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @card = tender_types(:card_standalone)
      pos_open_inventory(store: @store, variant: @variant, quantity: 5, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
    end

    test "card amount mismatch durable void_required then confirmation restores usability" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents

      mismatch = AddCardTender.call(
        pos_transaction: txn, tender_type: @card, amount_cents: net + 500,
        authorization_code: "AUTH-MISMATCH-INT", actor: @admin
      )
      refute mismatch.success?
      assert mismatch.requires_void_confirmation?
      tender = mismatch.pos_tender
      assert tender.present?
      assert tender.void_required?
      assert_equal "AUTH-MISMATCH-INT", tender.authorization_code
      assert txn.reload.void_required_tenders?
      refute txn.editable?

      workspace = WorkspacePresentation.for(pos_transaction: txn, presentation_param: "tender")
      assert_equal "recovery", workspace.state

      confirmed = RecordVoidedCardTender.call(
        pos_tender: tender, actor: @admin, external_void_confirmed: true,
        external_void_reference: "TERM-VOID-1"
      )
      assert confirmed.success?, confirmed.error
      assert_equal "voided", confirmed.pos_tender.status
      assert_equal "AUTH-MISMATCH-INT", confirmed.pos_tender.authorization_code
      refute txn.reload.void_required_tenders?

      after = WorkspacePresentation.for(pos_transaction: txn)
      assert_equal "transaction", after.state
      assert txn.editable?

      cash = tender_types(:cash)
      add_cash = AddCashTender.call(
        pos_transaction: txn, tender_type: cash, amount_tendered_cents: net, actor: @admin
      )
      assert add_cash.success?, add_cash.error
    end
  end
end
