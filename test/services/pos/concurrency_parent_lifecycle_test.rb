# frozen_string_literal: true

require "test_helper"

module Pos
  # Parent-before-child locking: OpenSession/OpenTransaction/RecallTransaction
  # must lock and recheck the parent under that lock so CloseBusinessDay /
  # CloseSession cannot leave orphans on closed parents.
  class ConcurrencyParentLifecycleTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all

      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @device_b = PosDevice.find_or_create_by!(store: @store, code: "REG-PARENT-B") do |device|
        device.name = "Parent Race Register B"
        device.device_type = "register"
        device.active = true
      end
    end

    teardown do
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all
    end

    test "concurrent open session versus close business day never opens on a closed day" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      results = {}

      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:open] = OpenSession.call(
              business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:close] = CloseBusinessDay.call(business_day: day, actor: @admin)
          end
        end
      ]
      threads.each(&:join)

      day.reload
      if results[:open].success?
        assert day.open?
        assert results[:open].pos_session.open?
        refute results[:close].success?
        assert_match(/POS session is open/, results[:close].error)
      else
        assert day.closed?
        assert results[:close].success?
        assert_match(/must be open/, results[:open].error)
        refute PosSession.where(business_day_id: day.id, status: "open").exists?
      end
    end

    test "concurrent open transaction versus close session never opens on a closed session" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
      ).pos_session
      results = {}

      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:open] = OpenTransaction.call(pos_session: session, actor: @admin)
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:close] = CloseSession.call(pos_session: session, actor: @admin)
          end
        end
      ]
      threads.each(&:join)

      session.reload
      if results[:open].success?
        assert session.open?
        assert results[:open].pos_transaction.open?
        refute results[:close].success?
        assert_match(/open transaction/, results[:close].error)
      else
        assert session.closed?
        assert results[:close].success?
        assert_match(/must be open/, results[:open].error)
        refute PosTransaction.where(active_pos_session_id: session.id, status: "open").exists?
      end
    end

    test "concurrent recall versus close session never attaches to a closed session" do
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session_a = OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
      ).pos_session
      session_b = OpenSession.call(
        business_day: day, store: @store, pos_device: @device_b, cashier: @admin, actor: @admin
      ).pos_session
      suspended = OpenTransaction.call(pos_session: session_a, actor: @admin).pos_transaction
      assert SuspendTransaction.call(pos_transaction: suspended, actor: @admin).success?
      results = {}

      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:recall] = RecallTransaction.call(
              pos_transaction: suspended, pos_session: session_b, actor: @admin
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:close] = CloseSession.call(pos_session: session_b, actor: @admin)
          end
        end
      ]
      threads.each(&:join)

      session_b.reload
      suspended.reload
      if results[:recall].success?
        assert session_b.open?
        assert suspended.open?
        assert_equal session_b.id, suspended.active_pos_session_id
        refute results[:close].success?
        assert_match(/open transaction/, results[:close].error)
      else
        assert session_b.closed?
        assert results[:close].success?
        assert_match(/must be open/, results[:recall].error)
        assert suspended.suspended?
        assert_nil suspended.active_pos_session_id
      end
    end
  end
end
