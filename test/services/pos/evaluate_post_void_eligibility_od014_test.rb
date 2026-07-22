# frozen_string_literal: true

require "test_helper"

module Pos
  class EvaluatePostVoidEligibilityOd014Test < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @card = tender_types(:card_standalone)
      IdentifierSequence.ensure_defaults!

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "blocks post-void when later sale further increases deficit after reviewed sale" do
      # Start empty with known cost, then two successive deficit sales.
      balance = StockBalance.find_or_create_by!(store: @store, product_variant: @variant) do |b|
        b.on_hand = 0
        b.reserved = 0
        b.unavailable = 0
      end
      balance.update!(
        on_hand: 0, reserved: 0, unavailable: 0,
        last_known_unit_cost_cents: 1000, last_known_cost_quality: "actual",
        open_provisional_deficit_cost_cents: 0, deficit_cost_quality: "unknown",
        inventory_value_cents: 0, cost_quality: "unknown", moving_average_cost_cents: nil
      )

      reviewed = complete_sale(quantity: 1, key: "od014-reviewed")
      later = complete_sale(quantity: 1, key: "od014-later")
      balance.reload
      assert_equal(-2, balance.on_hand)
      assert_equal 2000, balance.open_provisional_deficit_cost_cents

      eligibility = EvaluatePostVoidEligibility.call(original_transaction: reviewed)
      refute eligibility.eligible?
      assert eligibility.blockers.any? { |b| b.include?("later activity changed") }, eligibility.blockers.inspect

      later_eligibility = EvaluatePostVoidEligibility.call(original_transaction: later)
      refute later_eligibility.blockers.any? { |b| b.include?("OD-014") }, later_eligibility.blockers.inspect
    end

    test "blocks post-void when original sale was non-deficit but reverse would settle current deficit" do
      pos_open_inventory(store: @store, variant: @variant, quantity: 1, unit_cost_cents: 1000, actor: @admin)
      original = complete_sale(quantity: 1, key: "od014-non-def")
      complete_sale(quantity: 1, key: "od014-opens-def")

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal(-1, balance.on_hand)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents

      eligibility = EvaluatePostVoidEligibility.call(original_transaction: original)
      refute eligibility.eligible?
      assert eligibility.blockers.any? { |b| b.include?("settle current deficit") }, eligibility.blockers.inspect
    end

    test "removed return lines do not block post-void" do
      pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
      sale = complete_sale(quantity: 1, key: "pv-removed-return-sale")
      sale_line = sale.pos_line_items.where(status: "completed").first

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      added = AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      )
      assert added.success?, added.error
      assert RemoveLine.call(pos_line_item: added.pos_line_item, actor: @admin).success?

      eligibility = EvaluatePostVoidEligibility.call(original_transaction: sale)
      refute eligibility.blockers.any? { |b| b.include?("pending linked return") }, eligibility.blockers.inspect
    end

    test "blocks post-void when linked return has authorized card refund" do
      pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-SALE", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "card-sale-pv-block"
      ).success?
      sale.reload
      original_tender = sale.pos_tenders.where(status: "completed").first
      sale_line = sale.pos_line_items.where(status: "completed").first

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      assert AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: refund_due,
        authorization_code: "AUTH-REFUND", actor: @admin,
        original_pos_tender: original_tender
      ).success?

      eligibility = EvaluatePostVoidEligibility.call(original_transaction: sale)
      refute eligibility.eligible?
      assert eligibility.blockers.any? { |b| b.include?("refund activity") || b.include?("pending linked return") },
             eligibility.blockers.inspect
    end

    private

    def complete_sale(quantity:, key:)
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: quantity, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: key
      ).success?
      txn.reload
    end
  end
end
