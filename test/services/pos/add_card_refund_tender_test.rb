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
      @reason = return_reasons(:unwanted)

      open_inventory(@variant, quantity: 5, unit_cost_cents: 400)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "records authorized card refund with new references linked to original" do
      sale, sale_card = complete_card_sale(key: "sale-card-rfnd")
      ret, due = open_linked_return(sale, quantity: 1)

      result = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        authorization_code: "RFND-1", terminal_reference: "TERM-R1",
        original_pos_tender: sale_card
      )
      assert result.success?, result.error
      tender = result.pos_tender
      assert tender.authorized?
      assert_equal "refunded", tender.direction
      assert_equal "RFND-1", tender.authorization_code
      assert_equal "TERM-R1", tender.terminal_reference
      assert_equal sale_card.id, tender.original_pos_tender_id
      refute_equal sale_card.authorization_code, tender.authorization_code
    end

    test "partial card refund leaves remaining refund balance" do
      sale, sale_card = complete_card_sale(key: "sale-partial-rfnd", quantity: 2)
      ret, due = open_linked_return(sale, quantity: 2)
      partial = due / 2

      first = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: partial, actor: @admin,
        authorization_code: "RFND-P1", original_pos_tender: sale_card
      )
      assert first.success?, first.error

      second = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due - partial, actor: @admin,
        authorization_code: "RFND-P2", original_pos_tender: sale_card
      )
      assert second.success?, second.error
    end

    test "amount over remaining refund balance requires void confirmation" do
      sale, sale_card = complete_card_sale(key: "sale-mismatch-rfnd")
      ret, due = open_linked_return(sale, quantity: 1)

      result = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due + 100, actor: @admin,
        authorization_code: "RFND-BIG", original_pos_tender: sale_card
      )
      refute result.success?
      assert result.requires_void_confirmation?
    end

    test "required tender references are enforced" do
      sale, sale_card = complete_card_sale(key: "sale-refs")
      ret, due = open_linked_return(sale, quantity: 1)

      result = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        authorization_code: "", original_pos_tender: sale_card
      )
      refute result.success?
      refute result.requires_void_confirmation?
      assert_match(/required/i, result.error)
    end

    test "missing refund exception approval after valid refs requires void confirmation" do
      sale, = complete_card_sale(key: "sale-exc-rfnd")
      ret, due = open_linked_return(sale, quantity: 1)

      result = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        authorization_code: "RFND-EXC"
        # no original_pos_tender and no exception approver
      )
      refute result.success?
      assert result.requires_void_confirmation?
      assert_match(/restore remaining original|exception/i, result.error)
      assert RecordVoidedCardTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        direction: "refunded", authorization_code: "RFND-EXC", external_void_confirmed: true
      ).success?
    end

    test "unlinked original tender after valid refs requires void confirmation" do
      sale, = complete_card_sale(key: "sale-linked")
      _other_sale, other_card = complete_card_sale(key: "sale-unlinked")
      ret, due = open_linked_return(sale, quantity: 1)

      result = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        authorization_code: "RFND-UNLINKED", original_pos_tender: other_card
      )
      refute result.success?
      assert result.requires_void_confirmation?
      assert_match(/not linked/, result.error)
      assert RecordVoidedCardTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        direction: "refunded", authorization_code: "RFND-UNLINKED", external_void_confirmed: true
      ).success?
    end

    test "record voided card refund retains refs after mismatch" do
      sale, = complete_card_sale(key: "sale-voided-rfnd")
      ret, due = open_linked_return(sale, quantity: 1)

      voided = RecordVoidedCardTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due + 50, actor: @admin,
        direction: "refunded", authorization_code: "RFND-VOID",
        external_void_confirmed: true, external_void_reference: "EXT-V1"
      )
      assert voided.success?, voided.error
      tender = voided.pos_tender
      assert_equal "voided", tender.status
      assert_equal "RFND-VOID", tender.authorization_code
      assert_equal "EXT-V1", tender.external_void_reference
      assert_equal due + 50, tender.amount_cents
    end

    private

    def complete_card_sale(key:, quantity: 1)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: quantity, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      assert AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: net,
        authorization_code: "SALE-#{key}", actor: @admin
      ).success?
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin, completion_idempotency_key: key
      ).success?
      sale.reload
      [ sale, sale.pos_tenders.settled.first ]
    end

    def open_linked_return(sale, quantity:)
      line = sale.pos_line_items.where(status: "completed").find_by!(line_kind: "product")
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: line, quantity: quantity,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      ).success?
      due = ActiveRecord::Base.transaction {
        -FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(ret.id))
          .recalculation.net_total_cents
      }
      [ ret, due ]
    end

    def open_inventory(variant, quantity:, unit_cost_cents:)
      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: variant, position: 0,
        quantity_delta: quantity, input_unit_cost_cents: unit_cost_cents,
        input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
    end
  end
end
