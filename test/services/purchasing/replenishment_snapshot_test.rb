# frozen_string_literal: true

require "test_helper"

module Purchasing
  class ReplenishmentSnapshotTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @variant = product_variants(:upc_product_standard)
    end

    test "returns zeroed stock columns and derived on_order when no stock balance exists" do
      snapshot = ReplenishmentSnapshot.call(store: @store, product_variant: @variant)

      assert_equal 0, snapshot.on_hand
      assert_equal 0, snapshot.reserved
      assert_equal 0, snapshot.unavailable
      assert_equal 0, snapshot.available
      assert_equal 0, snapshot.on_order
      assert_equal @variant.regular_price_cents, snapshot.selling_price_cents
      assert_equal product_variant_vendors(:upc_product_ingram).expected_unit_cost_cents, snapshot.expected_unit_cost_cents
    end

    test "reflects stock balance quantities and on-order from ordered purchase order lines" do
      StockBalance.create!(store: @store, product_variant: @variant, on_hand: 12, reserved: 2, unavailable: 1,
                            inventory_value_cents: nil)
      PurchaseOrderLine.create!(
        purchase_order: purchase_orders(:ordered_po), product_variant: @variant, position: 0,
        ordered_quantity: 8, received_quantity: 3, cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 500
      )

      snapshot = ReplenishmentSnapshot.call(store: @store, product_variant: @variant)

      assert_equal 12, snapshot.on_hand
      assert_equal 2, snapshot.reserved
      assert_equal 1, snapshot.unavailable
      assert_equal 9, snapshot.available
      assert_equal 5, snapshot.on_order
    end
  end
end
