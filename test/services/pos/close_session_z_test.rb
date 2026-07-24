# frozen_string_literal: true

require "test_helper"

module Pos
  class CloseSessionZTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)

      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 2500, moving_average_cost_cents: 500, cost_quality: "actual"
      )

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "close persists Session Z atomically and is idempotent" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "z-1"
      ).success?

      before_z = @store.reload.next_session_z_number
      result = CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: net)
      assert result.success?, result.error
      refute result.replayed
      assert result.pos_session_z_report.present?
      assert_equal before_z, result.pos_session_z_report.z_number
      assert_equal before_z + 1, @store.reload.next_session_z_number
      assert_equal Reporting::ReportDefinition::VERSION, result.pos_session_z_report.report_definition_version
      assert_equal @session.id, result.pos_session_z_report.payload["pos_session_id"]

      replay = CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: net)
      assert replay.success?
      assert replay.replayed
      assert_equal result.pos_session_z_report.id, replay.pos_session_z_report.id
      assert_equal 1, PosSessionZReport.where(pos_session_id: @session.id).count
    end

    test "close requires pos.session.close permission" do
      editor = users(:catalog_editor)
      result = CloseSession.call(pos_session: @session, actor: editor, counted_cash_cents: 0)
      assert_not result.success?
      assert_match(/missing permission/, result.error)
    end
  end
end
