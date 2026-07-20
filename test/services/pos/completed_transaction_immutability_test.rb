# frozen_string_literal: true

require "test_helper"

module Pos
  # Phase 4g-1: completed transactions reject commercial mutation.
  class CompletedTransactionImmutabilityTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @department = departments(:books_new)

      pos_open_inventory(
        store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin
      )
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      @transaction, @line, _net = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "immut-sale"
      )
    end

    test "service mutations on a completed transaction fail without changing snapshots" do
      snapshot = @line.attributes.slice(
        "quantity", "unit_price_cents", "discount_amount_cents", "tax_amount_cents",
        "status", "cost_unit_cost_cents", "cost_extended_cents"
      )
      receipt = @transaction.receipt_number

      refute AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin
      ).success?
      refute UpdateLineQty.call(pos_line_item: @line, quantity: 2, actor: @admin).success?
      refute RemoveLine.call(pos_line_item: @line, actor: @admin, reason: "nope").success?
      refute ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: @line,
        method: "fixed_amount", amount_cents: 50, actor: @admin
      ).success?
      refute OverridePrice.call(
        pos_line_item: @line, requested_unit_price_cents: 100, actor: @admin
      ).success?
      refute AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 100, actor: @admin
      ).success?
      refute SuspendTransaction.call(pos_transaction: @transaction, actor: @admin).success?
      refute CancelTransaction.call(pos_transaction: @transaction, actor: @admin).success?

      @transaction.reload
      @line.reload
      assert @transaction.completed?
      assert_equal receipt, @transaction.receipt_number
      assert_equal snapshot, @line.attributes.slice(*snapshot.keys)
    end
  end
end
