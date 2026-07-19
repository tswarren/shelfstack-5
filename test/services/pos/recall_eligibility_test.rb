# frozen_string_literal: true

require "test_helper"

module Pos
  class RecallEligibilityTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @variant = product_variants(:sample_book_standard)

      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: @variant, position: 0, quantity_delta: 2,
        input_unit_cost_cents: 500, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "completion blocks when variant becomes ineligible after add" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(pos_transaction: txn, tender_type: tender_types(:cash), amount_tendered_cents: net, actor: @admin)

      @variant.update!(status: "inactive")

      result = CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "elig-1"
      )
      refute result.success?
      assert_match(/not eligible for sale/, result.error)
      assert_match(/variant_inactive/, result.error)
      assert line.reload.pending?
    end

    test "recall refreshes catalog price unless price was overridden" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item
      original_price = line.unit_price_cents
      assert SuspendTransaction.call(pos_transaction: txn, actor: @admin).success?

      @variant.update!(regular_price_cents: original_price + 250)

      recall = RecallTransaction.call(pos_transaction: txn, pos_session: @session, actor: @admin)
      assert recall.success?, recall.error
      assert_equal original_price + 250, line.reload.unit_price_cents
      assert recall.changes.any? { |c| c.field == "unit_price_cents" }
    end

    test "recall preserves approved price override" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item
      original_price = line.unit_price_cents
      override = OverridePrice.call(
        pos_line_item: line, requested_unit_price_cents: original_price - 100, actor: @admin, reason: "match competitor"
      )
      assert override.success?, override.error
      assert line.reload.price_overridden?

      assert SuspendTransaction.call(pos_transaction: txn, actor: @admin).success?
      @variant.update!(regular_price_cents: original_price + 500)

      recall = RecallTransaction.call(pos_transaction: txn, pos_session: @session, actor: @admin)
      assert recall.success?, recall.error
      assert_equal original_price - 100, line.reload.unit_price_cents
    end
  end
end
