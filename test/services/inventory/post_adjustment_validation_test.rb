# frozen_string_literal: true

require "test_helper"

module Inventory
  class PostAdjustmentValidationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @variant = product_variants(:sample_book_standard)
    end

    test "zero quantity opening fails without raising" do
      adjustment = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @user
      )
      # Bypass model validation to simulate bad persisted draft.
      line = adjustment.inventory_adjustment_lines.new(
        product_variant: @variant,
        position: 0,
        quantity_delta: 0,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      line.save!(validate: false)

      result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
      refute result.success?
      assert_match(/positive/i, result.error)
    end

    test "cost correction with changed aggregate conflicts on idempotent key" do
      open = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @user
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: open,
        product_variant: @variant,
        position: 0,
        quantity_delta: 3,
        input_unit_cost_cents: 300,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert PostAdjustment.call(adjustment: open, actor: @user, store: @store).success?

      correction = InventoryAdjustment.create!(
        store: @store,
        kind: "cost_correction",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:cost_documented),
        note: "Invoice",
        created_by_user: @user,
        posting_key: "inventory-adjustment:fixed-key"
      )
      line = InventoryAdjustmentLine.create!(
        inventory_adjustment: correction,
        product_variant: @variant,
        position: 0,
        quantity_delta: 0,
        corrected_inventory_value_cents: 1000,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )

      first = PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "cost_correction",
        movement_kind: :cost_correction,
        quantity_delta: 0,
        corrected_inventory_value_cents: 1000,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: line,
        posting_key: "#{correction.posting_key}:line:#{line.id}",
        posted_by_user: @user
      )
      refute first.replayed

      assert_raises(PostLedgerEntry::IdempotencyConflictError) do
        PostLedgerEntry.call(
          store: @store,
          product_variant: @variant,
          movement_type: "cost_correction",
          movement_kind: :cost_correction,
          quantity_delta: 0,
          corrected_inventory_value_cents: 1200,
          incoming_cost_method: "explicit",
          incoming_cost_quality: "actual",
          source: line,
          posting_key: "#{correction.posting_key}:line:#{line.id}",
          posted_by_user: @user
        )
      end
    end
  end
end
