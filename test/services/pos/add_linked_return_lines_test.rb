# frozen_string_literal: true

require "test_helper"

module Pos
  class AddLinkedReturnLinesTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @reason = return_reasons(:defective)

      pos_open_inventory(store: @store, variant: @variant, quantity: 3, unit_cost_cents: 500, actor: @admin)

      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      @sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @line_a = AddLine.call(pos_transaction: @sale, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
      net = RecalculateTransaction.call(pos_transaction: @sale).net_total_cents
      AddCashTender.call(pos_transaction: @sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: @sale, pos_session: @session, actor: @admin, completion_idempotency_key: "batch-sale-1"
      )
      @line_a.reload
    end

    test "batch adds multiple linked return lines atomically" do
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLines.call(
        pos_transaction: ret,
        actor: @admin,
        lines: [
          AddLinkedReturnLines::LineSpec.new(
            original_pos_line_item: @line_a, quantity: 1,
            return_reason: @reason, return_disposition: "return_to_stock"
          ),
          AddLinkedReturnLines::LineSpec.new(
            original_pos_line_item: @line_a, quantity: 1,
            return_reason: @reason, return_disposition: "damaged"
          )
        ]
      )
      assert result.success?, result.error
      assert_equal 2, result.pos_line_items.size
      assert_equal 2, ret.pos_line_items.returns.count
    end

    test "batch rolls back all lines when one fails" do
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLines.call(
        pos_transaction: ret,
        actor: @admin,
        lines: [
          AddLinkedReturnLines::LineSpec.new(
            original_pos_line_item: @line_a, quantity: 1,
            return_reason: @reason, return_disposition: "return_to_stock"
          ),
          AddLinkedReturnLines::LineSpec.new(
            original_pos_line_item: @line_a, quantity: 99,
            return_reason: @reason, return_disposition: "return_to_stock"
          )
        ]
      )
      refute result.success?
      assert_match(/exceeds remaining/i, result.error)
      assert_equal 0, ret.pos_line_items.returns.count
    end
  end
end
