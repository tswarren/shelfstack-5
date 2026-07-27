# frozen_string_literal: true

require "test_helper"

module Pos
  class ProductLookupResultsTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @other_store = stores(:warehouse)
      @admin = users(:admin)
      @variant = product_variants(:sample_book_standard)
      @unit_variant = product_variants(:signed_book_standard)
    end

    test "groups variants with price availability and eligibility" do
      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 4, reserved: 1, unavailable: 0,
        inventory_value_cents: 2000, moving_average_cost_cents: 500, cost_quality: "actual"
      )

      result = ProductLookupResults.call(
        organization: @store.organization,
        store: @store,
        query: @variant.sku
      )

      assert_equal 1, result.groups.size
      row = result.groups.first.variants.first
      assert_equal @variant.id, row.product_variant_id
      assert_equal @variant.regular_price_cents, row.price_cents
      assert_equal 3, row.available_quantity
      assert row.addable?
      assert_includes ProductLookupResults.as_scan_candidates(result).first["variants"].first.keys, "addable"
    end

    test "individual variant without exact unit is not addable" do
      result = ProductLookupResults.call(
        organization: @store.organization,
        store: @store,
        query: @unit_variant.sku
      )

      row = result.groups.first.variants.first
      refute row.addable?
      assert_includes row.blockers, "exact inventory unit required"
      assert_nil row.inventory_unit_id
    end

    test "eligible current-store unit is addable" do
      unit = Inventory::CreateInventoryUnit.call(
        store: @store, product_variant: @unit_variant, actor: @admin, acquisition_cost_cents: 900
      ).inventory_unit

      result = ProductLookupResults.call(
        organization: @store.organization,
        store: @store,
        query: unit.unit_identifier
      )

      row = result.groups.first.variants.first
      assert row.addable?
      assert_equal unit.id, row.inventory_unit_id
    end

    test "unit at another store is not addable" do
      created = Inventory::CreateInventoryUnit.call(
        store: @other_store,
        product_variant: @unit_variant,
        actor: @admin,
        acquisition_cost_cents: 900,
        require_unit_manage_permission: false
      )
      assert created.success?, created.error
      unit = created.inventory_unit

      result = ProductLookupResults.call(
        organization: @store.organization,
        store: @store,
        query: unit.unit_identifier
      )

      row = result.groups.first.variants.first
      refute row.addable?
      assert_includes row.blockers, "unit belongs to another store"
      assert_nil row.inventory_unit_id
    end

    test "sold or reserved unit is not addable" do
      unit = Inventory::CreateInventoryUnit.call(
        store: @store, product_variant: @unit_variant, actor: @admin, acquisition_cost_cents: 900
      ).inventory_unit
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = OpenSession.call(
        business_day: day, store: @store, pos_device: pos_devices(:register_1),
        cash_drawer: cash_drawers(:drawer_1), opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      txn = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @unit_variant, inventory_unit: unit, quantity: 1, actor: @admin)
      unit.reload
      assert_equal "reserved", unit.status

      result = ProductLookupResults.call(
        organization: @store.organization,
        store: @store,
        query: unit.unit_identifier
      )

      row = result.groups.first.variants.first
      refute row.addable?
      assert_includes row.blockers, "unit is reserved"
      assert_nil row.inventory_unit_id
    end
  end
end
