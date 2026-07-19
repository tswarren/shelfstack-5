# frozen_string_literal: true

require "test_helper"

module Pos
  # ApplyDiscount must compute remaining capacity under the transaction lock so
  # two concurrent large discounts cannot both observe full remaining capacity.
  class ConcurrencyApplyDiscountTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      PosDiscountAllocation.delete_all
      PosDiscount.delete_all
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all

      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @department = departments(:books_new)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department, unit_price_cents: 1000, actor: @admin
      ).pos_line_item
    end

    teardown do
      PosDiscountAllocation.delete_all
      PosDiscount.delete_all
      PosTender.delete_all
      PosLineItemTax.delete_all
      PosLineItem.delete_all
      PosTransaction.delete_all
      PosSession.delete_all
      BusinessDay.delete_all
    end

    test "concurrent fixed discounts cannot over-allocate line capacity" do
      results = []
      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results << ApplyDiscount.call(
              pos_transaction: @transaction,
              scope: "line",
              pos_line_item: @line,
              method: "fixed_amount",
              amount_cents: 600,
              actor: @admin
            )
          end
        end
      end
      threads.each(&:join)

      successes = results.select(&:success?)
      assert_equal 2, successes.size, results.map(&:error).inspect

      total = PosDiscountAllocation.where(pos_line_item_id: @line.id).sum(:allocated_amount_cents)
      assert_equal 1000, total
      assert_equal [ 600, 400 ].sort, successes.map { |r| r.pos_discount.applied_amount_cents }.sort

      recalc = RecalculateTransaction.call(pos_transaction: @transaction.reload)
      assert recalc.success?, recalc.blockers.inspect
      assert_operator recalc.net_total_cents, :>=, 0
    end
  end
end
