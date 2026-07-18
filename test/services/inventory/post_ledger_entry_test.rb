# frozen_string_literal: true

require "test_helper"

module Inventory
  class PostLedgerEntryTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @variant = product_variants(:sample_book_standard)
      @user = users(:admin)
      @reason = inventory_adjustment_reasons(:opening_initial)
      @adjustment = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: @reason,
        created_by_user: @user
      )
      @line = InventoryAdjustmentLine.create!(
        inventory_adjustment: @adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 2,
        input_unit_cost_cents: 500,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
    end

    test "posts opening and updates balance" do
      result = PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "test-open-1",
        posted_by_user: @user,
        reason_code: "opening_inventory.initial_opening_balance"
      )

      refute result.replayed
      balance = result.stock_balance
      assert_equal 2, balance.on_hand
      assert_equal 1000, balance.inventory_value_cents
      assert_equal 500, balance.moving_average_cost_cents
      assert_equal "actual", balance.cost_quality
      assert_equal 1000, result.ledger_entry.inventory_value_delta_cents
    end

    test "idempotent retry returns original" do
      PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "test-open-2",
        posted_by_user: @user
      )

      result = PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "test-open-2",
        posted_by_user: @user
      )

      assert result.replayed
      assert_equal 1, InventoryLedgerEntry.where(posting_key: "test-open-2").count
      assert_equal 2, StockBalance.find_by!(store: @store, product_variant: @variant).on_hand
    end

    test "conflicting idempotency key raises" do
      PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "test-open-3",
        posted_by_user: @user
      )

      assert_raises(PostLedgerEntry::IdempotencyConflictError) do
        PostLedgerEntry.call(
          store: @store,
          product_variant: @variant,
          movement_type: "opening_inventory",
          quantity_delta: 5,
          incoming_unit_cost_cents: 500,
          incoming_cost_method: "explicit",
          incoming_cost_quality: "actual",
          source: @line,
          posting_key: "test-open-3",
          posted_by_user: @user
        )
      end
    end

    test "same key with different unit cost conflicts" do
      PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "test-open-cost",
        posted_by_user: @user
      )

      assert_raises(PostLedgerEntry::IdempotencyConflictError) do
        PostLedgerEntry.call(
          store: @store,
          product_variant: @variant,
          movement_type: "opening_inventory",
          quantity_delta: 2,
          incoming_unit_cost_cents: 600,
          incoming_cost_method: "explicit",
          incoming_cost_quality: "actual",
          source: @line,
          posting_key: "test-open-cost",
          posted_by_user: @user
        )
      end
    end

    test "last_known stores resulting average not inbound unit" do
      PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 100,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "test-avg-1",
        posted_by_user: @user
      )

      adjustment2 = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: @reason,
        created_by_user: @user
      )
      line2 = InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment2,
        product_variant: @variant,
        position: 0,
        quantity_delta: 2,
        input_unit_cost_cents: 300,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )

      result = PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 300,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: line2,
        posting_key: "test-avg-2",
        posted_by_user: @user
      )

      assert_equal 200, result.stock_balance.moving_average_cost_cents
      assert_equal 200, result.stock_balance.last_known_unit_cost_cents
      assert_equal "actual", result.stock_balance.last_known_cost_quality
    end

    test "zero quantity movement returns service error not 500" do
      error = assert_raises(PostLedgerEntry::Error) do
        PostLedgerEntry.call(
          store: @store,
          product_variant: @variant,
          movement_type: "quantity_adjustment",
          quantity_delta: 0,
          source: @line,
          posting_key: "test-zero",
          posted_by_user: @user
        )
      end
      assert_match(/non-zero/i, error.message)
    end
  end
end
