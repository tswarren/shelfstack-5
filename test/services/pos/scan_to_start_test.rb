# frozen_string_literal: true

require "test_helper"

module Pos
  class ScanToStartTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "resolved scan opens transaction and adds line" do
      assert_difference -> { PosTransaction.count }, 1 do
        result = ScanToStart.call(pos_session: @session, actor: @admin, query: @variant.sku, quantity: 1)
        assert result.success?, result.error
        assert_equal "added", result.outcome
        assert result.pos_transaction.open?
        assert_equal 1, result.pos_transaction.pos_line_items.pending.count
      end
    end

    test "not found leaves no empty transaction" do
      before = PosTransaction.open_transactions.where(active_pos_session: @session).count
      result = ScanToStart.call(pos_session: @session, actor: @admin, query: "ZZZ-NO-SUCH-SKU-999", quantity: 1)
      assert_not result.success?
      assert_equal "failed", result.outcome
      assert_equal before, PosTransaction.open_transactions.where(active_pos_session: @session).count
    end

    test "existing open transaction reuses it" do
      first = ScanToStart.call(pos_session: @session, actor: @admin, query: @variant.sku)
      assert first.success?, first.error
      second = ScanToStart.call(pos_session: @session, actor: @admin, query: @variant.sku, quantity: 1)
      assert second.success?, second.error
      assert_equal first.pos_transaction.id, second.pos_transaction.id
      assert_operator second.pos_transaction.pos_line_items.pending.count, :>=, 2
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
        input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
    end
  end
end
