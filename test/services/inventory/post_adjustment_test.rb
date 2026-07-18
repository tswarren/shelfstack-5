# frozen_string_literal: true

require "test_helper"

module Inventory
  class PostAdjustmentTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @variant = product_variants(:sample_book_standard)
    end

    test "posts opening inventory and creates sellable on hand" do
      adjustment = build_adjustment(kind: "opening_inventory", reason: inventory_adjustment_reasons(:opening_initial))
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 5,
        input_unit_cost_cents: 200,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )

      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)

      assert result.success?, result.error
      assert adjustment.reload.posted?
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 5, balance.on_hand
      assert_equal 1000, balance.inventory_value_cents
      assert_equal "opening_inventory.initial_opening_balance", InventoryLedgerEntry.last.reason_code
      assert_equal "initial_opening_balance", adjustment.reason_code_snapshot
    end

    test "draft with required note may omit note until post" do
      adjustment = build_adjustment(kind: "opening_inventory", reason: inventory_adjustment_reasons(:opening_other), note: nil)
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 1,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )

      assert adjustment.persisted?
      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      refute result.success?
      assert_match(/note/i, result.error)

      adjustment.update!(note: "Migration batch A")
      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      assert result.success?, result.error
    end

    test "inactive reason blocks posting" do
      reason = inventory_adjustment_reasons(:opening_initial)
      adjustment = build_adjustment(kind: "opening_inventory", reason: reason)
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 1,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      reason.update_column(:active, false)

      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      refute result.success?
      assert_match(/inactive/i, result.error)
    end

    test "cost correction requires aggregate value and permissions" do
      open_stock!(qty: 3, unit_cost: 300)

      adjustment = build_adjustment(
        kind: "cost_correction",
        reason: inventory_adjustment_reasons(:cost_documented),
        note: "Invoice 123"
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 0,
        corrected_inventory_value_cents: 1000,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )

      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      assert result.success?, result.error
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 1000, balance.inventory_value_cents
      assert_equal 3, balance.on_hand
      assert_equal 333, balance.moving_average_cost_cents
    end

    test "duplicate variant lines rejected" do
      adjustment = build_adjustment(kind: "quantity_only", reason: inventory_adjustment_reasons(:quantity_shortage))
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: -1
      )

      assert_raises(ActiveRecord::RecordInvalid) do
        InventoryAdjustmentLine.create!(
          inventory_adjustment: adjustment,
          product_variant: @variant,
          position: 1,
          quantity_delta: -1
        )
      end
    end

    test "posted snapshots survive reason rename" do
      reason = inventory_adjustment_reasons(:opening_initial)
      adjustment = build_adjustment(kind: "opening_inventory", reason: reason)
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 1,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store).success?
      reason.update!(name: "Renamed Opening")
      assert_equal "Initial Opening Balance", adjustment.reload.reason_name_snapshot
    end

    test "idempotent post does not duplicate audit" do
      adjustment = build_adjustment(kind: "opening_inventory", reason: inventory_adjustment_reasons(:opening_initial))
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 1,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store).success?
      before = AdministrativeAuditEvent.where(action: "inventory.adjustment.posted").count
      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      assert result.success?
      assert result.replayed
      assert_equal before, AdministrativeAuditEvent.where(action: "inventory.adjustment.posted").count
    end

    private

    def build_adjustment(kind:, reason:, note: nil)
      InventoryAdjustment.create!(
        store: @store,
        kind: kind,
        status: "draft",
        inventory_adjustment_reason: reason,
        note: note,
        created_by_user: @user
      )
    end

    def open_stock!(qty:, unit_cost:)
      adjustment = build_adjustment(kind: "opening_inventory", reason: inventory_adjustment_reasons(:opening_initial))
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: qty,
        input_unit_cost_cents: unit_cost,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      raise result.error unless result.success?
    end
  end
end
