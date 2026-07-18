# frozen_string_literal: true

require "test_helper"

module Pos
  class BusinessDayAndSessionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
    end

    test "opens a business day with explicit reporting date" do
      result = OpenBusinessDay.call(store: @store, actor: @admin, reporting_date: Date.new(2026, 7, 19))
      assert result.success?
      assert_equal "open", result.business_day.status
      assert_equal Date.new(2026, 7, 19), result.business_day.reporting_date
    end

    test "only one open business day per store" do
      first = OpenBusinessDay.call(store: @store, actor: @admin)
      assert first.success?

      second = OpenBusinessDay.call(store: @store, actor: @admin)
      refute second.success?
      assert_match(/already open/, second.error)
    end

    test "business day cannot close while a session is open" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin).pos_session

      result = CloseBusinessDay.call(business_day: day, actor: @admin)
      refute result.success?
      assert_match(/POS session is open/, result.error)

      CloseSession.call(pos_session: session, actor: @admin)
      result = CloseBusinessDay.call(business_day: day, actor: @admin)
      assert result.success?
    end

    test "closing an already-closed business day is idempotent" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      first = CloseBusinessDay.call(business_day: day, actor: @admin)
      assert first.success?
      refute first.replayed

      second = CloseBusinessDay.call(business_day: day, actor: @admin)
      assert second.success?
      assert second.replayed
    end

    test "one open session per device" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      first = OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin)
      assert first.success?

      second = OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin)
      refute second.success?
      assert_match(/already has an open session/, second.error)
    end

    test "one active cash-enabled session per drawer" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      other_device = PosDevice.create!(store: @store, code: "REG2", name: "Register 2", device_type: "register", active: true)

      first = OpenSession.call(business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer, cashier: @admin, actor: @admin)
      assert first.success?

      second = OpenSession.call(business_day: day, store: @store, pos_device: other_device, cash_drawer: @drawer, cashier: @admin, actor: @admin)
      refute second.success?
      assert_match(/active cash-enabled session/, second.error)
    end

    test "session close blocked while it controls an open transaction" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin).pos_session
      OpenTransaction.call(pos_session: session, actor: @admin)

      result = CloseSession.call(pos_session: session, actor: @admin)
      refute result.success?
      assert_match(/open transaction/, result.error)
    end

    test "session close does not wipe suspended transactions" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin).pos_session
      transaction = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      assert SuspendTransaction.call(pos_transaction: transaction, actor: @admin).success?

      result = CloseSession.call(pos_session: session, actor: @admin)
      assert result.success?

      transaction.reload
      assert transaction.suspended?
      assert_nil transaction.active_pos_session_id
    end
  end
end
