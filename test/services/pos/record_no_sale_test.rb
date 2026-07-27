# frozen_string_literal: true

require "test_helper"

module Pos
  class RecordNoSaleTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "records one event and one audit event without cash movement" do
      assert_difference -> { PosNoSaleEvent.count }, 1 do
        assert_difference -> { AdministrativeAuditEvent.where(action: "pos.no_sale.recorded").count }, 1 do
          assert_no_difference -> { PosCashMovement.count } do
            result = RecordNoSale.call(
              pos_session: @session,
              actor: @admin,
              reason: "Customer change",
              idempotency_key: "no-sale-1"
            )
            assert result.success?, result.error
            assert_not result.replayed
            assert_equal "Customer change", result.pos_no_sale_event.reason
            assert_equal @session.id, result.pos_no_sale_event.pos_session_id
            assert result.pos_no_sale_event.occurred_at.present?
          end
        end
      end
    end

    test "same payload replays; changed payload conflicts" do
      first = RecordNoSale.call(
        pos_session: @session, actor: @admin, reason: "First", idempotency_key: "dup-key"
      )
      assert first.success?, first.error

      assert_no_difference -> { PosNoSaleEvent.count } do
        replay = RecordNoSale.call(
          pos_session: @session, actor: @admin, reason: "First", idempotency_key: "dup-key"
        )
        assert replay.success?, replay.error
        assert replay.replayed
        assert_equal first.pos_no_sale_event.id, replay.pos_no_sale_event.id
      end

      conflict = RecordNoSale.call(
        pos_session: @session, actor: @admin, reason: "Second", idempotency_key: "dup-key"
      )
      assert_not conflict.success?
      assert_match(/conflicts/i, conflict.error)
    end

    test "idempotency key is scoped to the session" do
      first = RecordNoSale.call(
        pos_session: @session, actor: @admin, reason: "Shared key", idempotency_key: "shared-key"
      )
      assert first.success?, first.error

      other_device = PosDevice.create!(
        store: @store, code: "REG-NOSALE-B", name: "No Sale B",
        device_type: "register", active: true
      )
      other_drawer = CashDrawer.create!(store: @store, code: "DRW-NOSALE-B", name: "Drawer B", active: true)
      other = OpenSession.call(
        business_day: @day, store: @store, pos_device: other_device, cash_drawer: other_drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session

      second = RecordNoSale.call(
        pos_session: other, actor: @admin, reason: "Shared key", idempotency_key: "shared-key"
      )
      assert second.success?, second.error
      assert_not_equal first.pos_no_sale_event.id, second.pos_no_sale_event.id
    end

    test "rejects blank reason" do
      result = RecordNoSale.call(
        pos_session: @session, actor: @admin, reason: "   ", idempotency_key: "blank-reason"
      )
      assert_not result.success?
      assert_match(/reason/i, result.error)
    end

    test "rejects closed session" do
      CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: 0)
      result = RecordNoSale.call(
        pos_session: @session.reload, actor: @admin, reason: "After close", idempotency_key: "closed"
      )
      assert_not result.success?
      assert_match(/not open/i, result.error)
    end

    test "rejects non-cash-enabled session" do
      other_device = PosDevice.create!(
        store: @store, code: "REG-NOSALE", name: "No Sale Register",
        device_type: "register", active: true
      )
      non_cash = OpenSession.call(
        business_day: @day, store: @store, pos_device: other_device,
        cash_drawer: nil, opening_cash_cents: nil, cashier: @admin, actor: @admin
      ).pos_session

      result = RecordNoSale.call(
        pos_session: non_cash, actor: @admin, reason: "No drawer", idempotency_key: "non-cash"
      )
      assert_not result.success?
      assert_match(/cash-enabled/i, result.error)
    end

    test "rejects missing permission" do
      editor = users(:catalog_editor)
      result = RecordNoSale.call(
        pos_session: @session, actor: editor, reason: "Denied", idempotency_key: "denied"
      )
      assert_not result.success?
      assert_match(/permission/i, result.error)
    end

    test "session closing race fails safely" do
      @session.update!(status: "closed", closed_at: Time.current, closed_by_user: @admin)
      result = RecordNoSale.call(
        pos_session: @session, actor: @admin, reason: "Race", idempotency_key: "race"
      )
      assert_not result.success?
      assert_match(/not open/i, result.error)
      assert_equal 0, PosNoSaleEvent.where(idempotency_key: "race").count
    end
  end
end
