# frozen_string_literal: true

require "test_helper"

module Pos
  class ConcurrencyRecallTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all

      @store = stores(:main_street)
      @admin = users(:admin)
      @device_a = pos_devices(:register_1)
      @device_b = PosDevice.find_or_create_by!(store: @store, code: "REG2") do |device|
        device.name = "Register 2"
        device.device_type = "register"
        device.active = true
      end

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session_a = OpenSession.call(business_day: @day, store: @store, pos_device: @device_a, cashier: @admin, actor: @admin).pos_session
      @session_b = OpenSession.call(business_day: @day, store: @store, pos_device: @device_b, cashier: @admin, actor: @admin).pos_session

      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      @suspended = SuspendTransaction.call(pos_transaction: transaction, actor: @admin).pos_transaction
    end

    teardown do
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all
    end

    test "concurrent recall of the same suspended transaction has exactly one winner" do
      results = []
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results << RecallTransaction.call(pos_transaction: @suspended, pos_session: @session_a, actor: @admin)
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results << RecallTransaction.call(pos_transaction: @suspended, pos_session: @session_b, actor: @admin)
          end
        end
      ]
      threads.each(&:join)

      successes = results.select(&:success?)
      failures = results.reject(&:success?)

      assert_equal 1, successes.size, results.map(&:error).inspect
      assert_equal 1, failures.size

      @suspended.reload
      assert @suspended.open?
      assert_includes [ @session_a.id, @session_b.id ], @suspended.active_pos_session_id
    end
  end
end
