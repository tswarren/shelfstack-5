# frozen_string_literal: true

require "test_helper"

module Pos
  class ProposeRefundPlanTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @reason = return_reasons(:defective)

      pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      @sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @sale_line = AddLine.call(pos_transaction: @sale, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item
      net = RecalculateTransaction.call(pos_transaction: @sale).net_total_cents
      AddCashTender.call(pos_transaction: @sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: @sale, pos_session: @session, actor: @admin, completion_idempotency_key: "plan-sale-1"
      )
      @sale_line.reload
    end

    test "proposes cash remainder for cash-only original sale" do
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret,
        original_pos_line_item: @sale_line,
        quantity: 1,
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin
      ).success?

      plan = ProposeRefundPlan.call(pos_transaction: ret)
      assert plan.refund_due_cents.positive?
      assert plan.rows.any?
      assert_equal :cash, plan.rows.first.destination
      assert_equal plan.refund_due_cents, plan.rows.sum(&:amount_cents)
    end
  end
end
