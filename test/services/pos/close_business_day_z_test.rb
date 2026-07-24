# frozen_string_literal: true

require "test_helper"

module Pos
  class CloseBusinessDayZTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @card = tender_types(:card_standalone)

      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 10, reserved: 0, unavailable: 0,
        inventory_value_cents: 5000, moving_average_cost_cents: 500, cost_quality: "actual"
      )

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "closes day without card prompt when no card tenders" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "day-cash-1"
      ).success?
      assert CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: net).success?

      before = @store.reload.next_business_day_z_number
      result = CloseBusinessDay.call(business_day: @day, actor: @admin)
      assert result.success?, result.error
      assert result.business_day_z_report.present?
      assert_equal before, result.business_day_z_report.z_number
      assert_equal [], result.business_day_z_report.payload["card_evidence"]
    end

    test "requires batch evidence or unavailable when card tenders exist" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCardTender.call(
        pos_transaction: txn, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH1", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "day-card-1"
      ).success?
      assert CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: 0).success?

      blocked = CloseBusinessDay.call(business_day: @day, actor: @admin)
      assert_not blocked.success?
      assert_match(/card evidence/, blocked.error)

      result = CloseBusinessDay.call(
        business_day: @day,
        actor: @admin,
        card_evidence: { mode: "recorded", net_cents: net, batch_reference: "B1" }
      )
      assert result.success?, result.error
      evidence = result.business_day_z_report.payload["card_evidence"]
      assert_equal 1, evidence.size
      assert_equal "recorded", evidence.first["status"]
      assert_equal net, evidence.first["net_cents"]
    end

    test "evidence_unavailable path records reason without inventing amounts" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCardTender.call(
        pos_transaction: txn, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH2", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "day-card-2"
      ).success?
      assert CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: 0).success?

      result = CloseBusinessDay.call(
        business_day: @day,
        actor: @admin,
        card_evidence: { mode: "unavailable", unavailable_reason: "Printer offline" }
      )
      assert result.success?, result.error
      row = PosCloseCardEvidence.find_by!(business_day: @day)
      assert_equal "unavailable", row.status
      assert_nil row.net_cents
    end
  end
end
