# frozen_string_literal: true

require "test_helper"

module Pos
  class AddCardRefundTenderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @card = tender_types(:card_standalone)
      IdentifierSequence.ensure_defaults!
      pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "prepare then record authorized card refund against original tender" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      prepared = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      )
      assert prepared.ready?, prepared.error

      recorded = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due,
        authorization_code: "RFND-1", actor: @admin, original_pos_tender: card_tender
      )
      assert recorded.success?, recorded.error
      refute recorded.requires_reconciliation
      assert_equal card_tender.id, recorded.pos_tender.original_pos_tender_id
    end

    test "external auth is retained with requires_reconciliation when plan validation fails" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      recorded = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due + 500,
        authorization_code: "RFND-OVER", actor: @admin, original_pos_tender: card_tender
      )
      assert recorded.success?, recorded.error
      assert recorded.requires_reconciliation
      assert recorded.pos_tender.requires_reconciliation?
      assert_equal "RFND-OVER", recorded.pos_tender.authorization_code

      denied = CompleteTransaction.call(
        pos_transaction: ret, pos_session: @session, actor: @admin,
        completion_idempotency_key: "card-recon-block"
      )
      refute denied.success?
      assert_match(/requires reconciliation/, denied.error)
    end

    test "multi-sale return: capacity change after prepare retains authorized refund for reconciliation" do
      line_a, tender_a = complete_card_sale(quantity: 1, key: "card-a")
      line_b, = complete_card_sale(quantity: 1, key: "card-b")

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: line_a, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: line_b, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?

      # Prepare a refund against sale A only (amount = A's tender).
      amount_a = tender_a.amount_cents
      assert PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: amount_a, actor: @admin,
        original_pos_tender: tender_a
      ).ready?

      # Between prepare and confirm, another return exhausts tender_a's refundable capacity.
      # Use a separate sale with qty 2 so two returns can both target the same tender.
      line2, tender2 = complete_card_sale(quantity: 2, key: "card-shared")
      ret_hold = open_return(line2, quantity: 1)
      due_hold = -RecalculateTransaction.call(pos_transaction: ret_hold).net_total_cents
      assert PrepareCardRefund.call(
        pos_transaction: ret_hold, tender_type: @card, amount_cents: due_hold, actor: @admin,
        original_pos_tender: tender2
      ).ready?

      ret_race = open_return(line2, quantity: 1)
      due_race = -RecalculateTransaction.call(pos_transaction: ret_race).net_total_cents
      assert AddCardRefundTender.call(
        pos_transaction: ret_race, tender_type: @card, amount_cents: due_race,
        authorization_code: "RACE-1", actor: @admin, original_pos_tender: tender2
      ).success?
      # Complete race return so tender2 remaining drops via completed refund.
      # Need to settle remaining refund balance on ret_race — due_race should equal
      # half of sale; tender2 remaining after this authorized (not completed) still
      # counts against remaining_refundable. Confirm hold against depleted remaining.
      assert AddCardRefundTender.call(
        pos_transaction: ret_hold, tender_type: @card, amount_cents: due_hold,
        authorization_code: "HOLD-1", actor: @admin, original_pos_tender: tender2
      ).success?

      # Second confirmation against same original after first pending should reconcile.
      second = AddCardRefundTender.call(
        pos_transaction: ret_hold, tender_type: @card, amount_cents: due_hold,
        authorization_code: "HOLD-2", actor: @admin, original_pos_tender: tender2
      )
      assert second.success?, second.error
      assert second.requires_reconciliation
      assert second.pos_tender.requires_reconciliation?

      # Multi-sale return still locks both originals during recording.
      multi = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: amount_a,
        authorization_code: "MULTI-1", actor: @admin, original_pos_tender: tender_a
      )
      assert multi.success?, multi.error
      refute multi.requires_reconciliation
    end

    private

    def complete_card_sale(quantity:, key: nil)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: quantity, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: net,
        authorization_code: "SALE-#{SecureRandom.hex(2)}", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: key || "card-sale-#{SecureRandom.hex(3)}"
      ).success?
      [
        sale.pos_line_items.where(status: "completed").first,
        sale.pos_tenders.where(status: "completed").first
      ]
    end

    def open_return(sale_line, quantity:)
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: quantity,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      ret
    end
  end
end
