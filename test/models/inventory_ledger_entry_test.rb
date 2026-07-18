# frozen_string_literal: true

require "test_helper"

class InventoryLedgerEntryTest < ActiveSupport::TestCase
  test "rejects updates after create" do
    store = stores(:main_street)
    variant = product_variants(:sample_book_standard)
    user = users(:admin)
    reason = inventory_adjustment_reasons(:opening_initial)
    adjustment = InventoryAdjustment.create!(
      store: store,
      kind: "opening_inventory",
      status: "draft",
      inventory_adjustment_reason: reason,
      created_by_user: user
    )
    line = InventoryAdjustmentLine.create!(
      inventory_adjustment: adjustment,
      product_variant: variant,
      position: 0,
      quantity_delta: 1,
      input_unit_cost_cents: 100,
      input_cost_method: "explicit",
      input_cost_quality: "actual"
    )

    entry = Inventory::PostLedgerEntry.call(
      store: store,
      product_variant: variant,
      movement_type: "opening_inventory",
      quantity_delta: 1,
      incoming_unit_cost_cents: 100,
      incoming_cost_method: "explicit",
      incoming_cost_quality: "actual",
      source: line,
      posting_key: "ledger-readonly-1",
      posted_by_user: user
    ).ledger_entry

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      entry.update!(reason_note: "mutated")
    end
  end
end
