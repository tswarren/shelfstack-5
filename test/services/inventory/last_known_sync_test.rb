# frozen_string_literal: true

require "test_helper"

module Inventory
  class LastKnownSyncTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @variant = product_variants(:sample_book_standard)
    end

    test "quantity-only outbound updates last_known to new carrying average" do
      open_stock!(qty: 3, unit_cost: 33) # value 99 if 33*3 — use explicit aggregate path via 100/3

      # Rebuild with aggregate 100 for the review example
      StockBalance.find_by!(store: @store, product_variant: @variant).update_columns(
        on_hand: 3,
        inventory_value_cents: 100,
        moving_average_cost_cents: 33,
        cost_quality: "actual",
        last_known_unit_cost_cents: 33,
        last_known_cost_quality: "actual"
      )

      adjustment = InventoryAdjustment.create!(
        store: @store,
        kind: "quantity_only",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:quantity_shortage),
        created_by_user: @user
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: -1
      )
      assert PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store).success?

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 2, balance.on_hand
      assert_equal 67, balance.inventory_value_cents
      assert_equal 34, balance.moving_average_cost_cents
      assert_equal 34, balance.last_known_unit_cost_cents
    end

    private

    def open_stock!(qty:, unit_cost:)
      adjustment = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @user
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: qty,
        input_unit_cost_cents: unit_cost,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store).success?
    end
  end
end
