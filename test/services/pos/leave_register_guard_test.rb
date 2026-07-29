# frozen_string_literal: true

require "test_helper"

module Pos
  class LeaveRegisterGuardTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @variant = product_variants(:sample_book_standard)
      IdentifierSequence.ensure_defaults!
      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: pos_devices(:register_1),
        cash_drawer: cash_drawers(:drawer_1), opening_cash_cents: 0,
        cashier: @admin, actor: @admin
      ).pos_session
    end

    test "allows leave when no open transaction" do
      result = LeaveRegisterGuard.evaluate(user: @admin, store: @store)
      assert_equal :allow, result.status
    end

    test "interrupts when open transaction has no unresolved tenders" do
      OpenTransaction.call(pos_session: @session, actor: @admin)
      result = LeaveRegisterGuard.evaluate(user: @admin, store: @store)
      assert_equal :interrupt, result.status
      assert result.pos_transaction.present?
    end

    test "blocks when unresolved tenders exist" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(
        pos_transaction: txn, tender_type: tender_types(:cash),
        amount_tendered_cents: net, actor: @admin
      )

      result = LeaveRegisterGuard.evaluate(user: @admin, store: @store)
      assert_equal :block, result.status
      assert_match(/tender/i, result.message)
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      reason = inventory_adjustment_reasons(:opening_initial)
      adjustment = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: reason, created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment, product_variant: variant, position: 0,
        quantity_delta: quantity, input_unit_cost_cents: unit_cost_cents,
        input_cost_method: "explicit", input_cost_quality: "actual"
      )
      result = Inventory::PostAdjustment.call(adjustment: adjustment, actor: @admin, store: @store)
      raise "open inventory failed: #{result.error}" unless result.success?
    end
  end
end
