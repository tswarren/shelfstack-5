# frozen_string_literal: true

require "test_helper"

module Pos
  class OverridePriceTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)

      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: @variant, position: 0, quantity_delta: 5,
        input_unit_cost_cents: 500, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "override within requester authority applies immediately and recalculates" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item

      result = OverridePrice.call(pos_line_item: line, requested_unit_price_cents: 1500, actor: @admin, reason: "damaged cover")

      assert result.success?
      assert_equal 1500, result.pos_line_item.reload.unit_price_cents
      assert_nil result.pos_approval
    end

    test "override beyond requester authority is denied without an approver and approved with one" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @clerk).pos_line_item

      denied = OverridePrice.call(
        pos_line_item: line, requested_unit_price_cents: 0, actor: @clerk, reason: "price match"
      )
      refute denied.success?
      assert_equal 1999, line.reload.unit_price_cents

      approved = OverridePrice.call(
        pos_line_item: line, requested_unit_price_cents: 1000, actor: @clerk, reason: "price match",
        approver: @admin, approver_pin: "1234"
      )
      assert approved.success?
      assert_equal 1000, line.reload.unit_price_cents
      assert_equal @admin, approved.pos_approval.approved_by_user
    end

    test "an incorrect approver pin is denied" do
      line = AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @clerk).pos_line_item

      result = OverridePrice.call(
        pos_line_item: line, requested_unit_price_cents: 1000, actor: @clerk, reason: "price match",
        approver: @admin, approver_pin: "0000"
      )
      refute result.success?
      assert_match(/credentials/, result.error)
    end
  end
end
