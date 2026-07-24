# frozen_string_literal: true

require "test_helper"

module Pos
  class ConcurrencyFindOrOpenActiveTransactionTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      cleanup!
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
    end

    teardown { cleanup! }

    test "concurrent find-or-open creates exactly one open transaction" do
      results = {}
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:a] = FindOrOpenActiveTransaction.call(
              pos_session: @session, actor: @admin, create_if_missing: true
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:b] = FindOrOpenActiveTransaction.call(
              pos_session: @session, actor: @admin, create_if_missing: true
            )
          end
        end
      ]
      threads.each(&:join)

      successes = results.values.select(&:success?)
      assert_equal 2, successes.size, results.transform_values { |r| [ r&.success?, r&.error ] }.inspect
      assert_equal 1, successes.map { |r| r.pos_transaction.id }.uniq.size
      assert_equal 1, PosTransaction.open_transactions.where(active_pos_session_id: @session.id).count
      assert_equal 1, successes.count(&:created?)
    end

    private

    def cleanup!
      PosDiscountAllocation.delete_all
      PosDiscount.delete_all
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSessionCashCount.delete_all
      purge_phase7_close_control_rows!
      PosSession.delete_all
      BusinessDay.delete_all
    end
  end
end
