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

    test "reverse restores original cost quality onto positive inventory" do
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "opening_inventory",
        quantity_delta: 5, incoming_unit_cost_cents: 400, incoming_cost_method: "explicit",
        incoming_cost_quality: "actual", source: @line, posting_key: "qual-open",
        posted_by_user: @user
      )
      sale = PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -5, source: @line, posting_key: "qual-sale",
        posted_by_user: @user
      )
      balance = sale.stock_balance.reload
      assert_equal 0, balance.on_hand
      assert_equal "unknown", balance.cost_quality

      ReverseLedgerEntry.call(
        reversal_of_entry: sale.ledger_entry,
        source: @line,
        posting_key: "qual-sale:reverse",
        posted_by_user: @user
      )
      balance.reload
      assert_equal 5, balance.on_hand
      assert_equal "actual", balance.cost_quality
      assert_equal 2000, balance.inventory_value_cents
    end

    test "unknown-cost deficit deepening persists prior pool for exact reverse" do
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "opening_inventory",
        quantity_delta: 1, incoming_unit_cost_cents: 1000, incoming_cost_method: "explicit",
        incoming_cost_quality: "actual", source: @line, posting_key: "unk-open",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "unk-to-zero",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "unk-prior",
        posted_by_user: @user
      )
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents

      # Clear last_known so the next sale posts with unknown provisional cost.
      balance.update!(last_known_unit_cost_cents: nil, last_known_cost_quality: "unknown")
      unknown_sale = PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "unk-sale",
        posted_by_user: @user
      )
      unknown_sale.stock_balance.reload
      assert_nil unknown_sale.stock_balance.open_provisional_deficit_cost_cents
      assert_equal 1000, unknown_sale.ledger_entry.prior_open_provisional_deficit_cost_cents

      ReverseLedgerEntry.call(
        reversal_of_entry: unknown_sale.ledger_entry,
        source: @line,
        posting_key: "unk-sale:reverse",
        posted_by_user: @user
      )
      balance.reload
      assert_equal(-1, balance.on_hand)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents
      assert_equal "actual", balance.deficit_cost_quality
    end

    test "OD-014 interim: refuses reverse of earlier deficit sale after later deficit increase" do
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "opening_inventory",
        quantity_delta: 1, incoming_unit_cost_cents: 1000, incoming_cost_method: "explicit",
        incoming_cost_quality: "actual", source: @line, posting_key: "later-def-open",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "later-def-zero",
        posted_by_user: @user
      )
      reviewed = PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "later-def-reviewed",
        posted_by_user: @user
      )
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      balance.update!(last_known_unit_cost_cents: 3000, last_known_cost_quality: "actual")
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "later-def-later",
        posted_by_user: @user
      )
      balance.reload
      assert_equal(-2, balance.on_hand)
      assert_equal 4000, balance.open_provisional_deficit_cost_cents

      error = assert_raises(ReverseLedgerEntry::ConflictError) do
        ReverseLedgerEntry.call(
          reversal_of_entry: reviewed.ledger_entry,
          source: @line,
          posting_key: "later-def-reviewed:reverse",
          posted_by_user: @user
        )
      end
      assert_match(/later deficit activity/, error.message)
      balance.reload
      assert_equal(-2, balance.on_hand)
      assert_equal 4000, balance.open_provisional_deficit_cost_cents
    end

    test "OD-014 interim: refuses reverse of deficit-reducing entry after later deficit increase" do
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "opening_inventory",
        quantity_delta: 1, incoming_unit_cost_cents: 1000, incoming_cost_method: "explicit",
        incoming_cost_quality: "actual", source: @line, posting_key: "red-open",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "red-zero",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -2, source: @line, posting_key: "red-deficit",
        posted_by_user: @user
      )
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal(-2, balance.on_hand)
      assert_equal 2000, balance.open_provisional_deficit_cost_cents

      returned = PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "customer_return",
        quantity_delta: 1, incoming_unit_cost_cents: 1000, incoming_cost_method: "explicit",
        incoming_cost_quality: "actual", source: @line, posting_key: "red-return",
        posted_by_user: @user
      )
      balance.reload
      assert_equal(-1, balance.on_hand)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents

      balance.update!(last_known_unit_cost_cents: 3000, last_known_cost_quality: "actual")
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "red-later",
        posted_by_user: @user
      )
      balance.reload
      assert_equal(-2, balance.on_hand)
      assert_equal 4000, balance.open_provisional_deficit_cost_cents

      error = assert_raises(ReverseLedgerEntry::ConflictError) do
        ReverseLedgerEntry.call(
          reversal_of_entry: returned.ledger_entry,
          source: @line,
          posting_key: "red-return:reverse",
          posted_by_user: @user
        )
      end
      assert_match(/later deficit activity/, error.message)
      balance.reload
      assert_equal(-2, balance.on_hand)
      assert_equal 4000, balance.open_provisional_deficit_cost_cents
    end

    test "reverse of unknown inventory-value sale preserves unknown value" do
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "opening_inventory",
        quantity_delta: 2, incoming_unit_cost_cents: nil, incoming_cost_method: "unknown",
        incoming_cost_quality: "unknown", source: @line, posting_key: "unk-val-open",
        posted_by_user: @user
      )
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_nil balance.inventory_value_cents
      assert_equal "unknown", balance.cost_quality

      sale = PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "unk-val-sale",
        posted_by_user: @user
      )
      assert_nil sale.ledger_entry.inventory_value_delta_cents
      balance.reload
      assert_equal 1, balance.on_hand
      assert_nil balance.inventory_value_cents

      reverse = ReverseLedgerEntry.call(
        reversal_of_entry: sale.ledger_entry,
        source: @line,
        posting_key: "unk-val-sale:reverse",
        posted_by_user: @user
      )
      assert_nil reverse.ledger_entry.inventory_value_delta_cents
      balance.reload
      assert_equal 2, balance.on_hand
      assert_nil balance.inventory_value_cents
      assert_equal "unknown", balance.cost_quality

      replay = ReverseLedgerEntry.call(
        reversal_of_entry: sale.ledger_entry,
        source: @line,
        posting_key: "unk-val-sale:reverse",
        posted_by_user: @user
      )
      assert replay.replayed
    end

    test "OD-014 interim: refuses reverse that would settle current deficit without original deficit change" do
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "opening_inventory",
        quantity_delta: 1, incoming_unit_cost_cents: 1000, incoming_cost_method: "explicit",
        incoming_cost_quality: "actual", source: @line, posting_key: "settle-open",
        posted_by_user: @user
      )
      original = PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "settle-original",
        posted_by_user: @user
      )
      PostLedgerEntry.call(
        store: @store, product_variant: @variant, movement_type: "sale",
        quantity_delta: -1, source: @line, posting_key: "settle-later",
        posted_by_user: @user
      )
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal(-1, balance.on_hand)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents

      error = assert_raises(ReverseLedgerEntry::ConflictError) do
        ReverseLedgerEntry.call(
          reversal_of_entry: original.ledger_entry,
          source: @line,
          posting_key: "settle-original:reverse",
          posted_by_user: @user
        )
      end
      assert_match(/settle current deficit/, error.message)
      balance.reload
      assert_equal(-1, balance.on_hand)
      assert_equal 1000, balance.open_provisional_deficit_cost_cents
    end
  end
end
