# frozen_string_literal: true

require "test_helper"

module Inventory
  class ReverseLedgerEntryTest < ActiveSupport::TestCase
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
        quantity_delta: 5,
        input_unit_cost_cents: 400,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
    end

    test "exact reverse restores on_hand value and unavailable" do
      open = PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 5,
        incoming_unit_cost_cents: 400,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "rev-open-1",
        posted_by_user: @user,
        unavailable_delta: 2,
        availability_reason: "inspection_required"
      )

      assert_equal 5, open.stock_balance.on_hand
      assert_equal 2, open.stock_balance.unavailable
      assert_equal 2, open.ledger_entry.unavailable_delta
      assert_equal 2, open.ledger_entry.resulting_unavailable

      result = ReverseLedgerEntry.call(
        reversal_of_entry: open.ledger_entry,
        source: @line,
        posting_key: "rev-open-1:reverse",
        posted_by_user: @user
      )

      refute result.replayed
      assert_equal open.ledger_entry.id, result.ledger_entry.reversal_of_entry_id
      assert_equal(-5, result.ledger_entry.quantity_delta)
      assert_equal(-2, result.ledger_entry.unavailable_delta)
      assert_equal 0, result.stock_balance.on_hand
      assert_equal 0, result.stock_balance.unavailable
      assert_equal 0, result.stock_balance.inventory_value_cents
    end

    test "idempotent reverse replay" do
      open = PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 3,
        incoming_unit_cost_cents: 400,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "rev-open-2",
        posted_by_user: @user
      )
      first = ReverseLedgerEntry.call(
        reversal_of_entry: open.ledger_entry,
        source: @line,
        posting_key: "rev-open-2:reverse",
        posted_by_user: @user
      )
      second = ReverseLedgerEntry.call(
        reversal_of_entry: open.ledger_entry,
        source: @line,
        posting_key: "rev-open-2:reverse",
        posted_by_user: @user
      )

      assert second.replayed
      assert_equal first.ledger_entry.id, second.ledger_entry.id
      assert_equal 1, InventoryLedgerEntry.where(reversal_of_entry_id: open.ledger_entry.id).count
    end

    test "second reverse of same entry is blocked" do
      open = PostLedgerEntry.call(
        store: @store,
        product_variant: @variant,
        movement_type: "opening_inventory",
        quantity_delta: 2,
        incoming_unit_cost_cents: 400,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual",
        source: @line,
        posting_key: "rev-open-3",
        posted_by_user: @user
      )
      ReverseLedgerEntry.call(
        reversal_of_entry: open.ledger_entry,
        source: @line,
        posting_key: "rev-open-3:reverse",
        posted_by_user: @user
      )

      assert_raises(ReverseLedgerEntry::ConflictError) do
        ReverseLedgerEntry.call(
          reversal_of_entry: open.ledger_entry,
          source: @line,
          posting_key: "rev-open-3:reverse-again",
          posted_by_user: @user
        )
      end
    end

    test "OD-014 Case 1: exact deficit reverse restores prior pool not proportional share" do
      # Open 1 @ $10, sell to zero (seeds last_known), sell into deficit @ $10.
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "opening_inventory",
        quantity_delta: 1, incoming_unit_cost_cents: 1000, incoming_cost_method: "explicit",
        incoming_cost_quality: "actual", source: @line, posting_key: "def-open",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "def-to-zero",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "def-prior",
        posted_by_user: @user
      )
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal(-1, balance.on_hand)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents

      # Deepen deficit with a second sale after last_known is raised to $20.
      balance.update!(last_known_unit_cost_cents: 2000, last_known_cost_quality: "actual")
      sale = PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "def-sale",
        posted_by_user: @user
      )
      balance.reload
      assert_equal(-2, balance.on_hand)
      assert_equal 3000, balance.open_provisional_deficit_cost_cents
      assert_equal 2000, sale.ledger_entry.unit_cost_cents

      # Exact reverse restores $10; proportional current-pool release would yield $15.
      ReverseLedgerEntry.call(
        reversal_of_entry: sale.ledger_entry,
        source: @line,
        posting_key: "def-sale:reverse",
        posted_by_user: @user
      )
      balance.reload
      assert_equal(-1, balance.on_hand)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents
    end
  end
end
