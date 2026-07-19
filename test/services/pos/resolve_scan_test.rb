# frozen_string_literal: true

require "test_helper"

module Pos
  class ResolveScanTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @org = @store.organization
      @admin = users(:admin)
      @variant = product_variants(:signed_book_standard)
    end

    test "resolves a generated 27 identifier to its inventory unit and variant" do
      unit = Inventory::CreateInventoryUnit.call(
        store: @store, product_variant: @variant, actor: @admin, acquisition_cost_cents: 900
      ).inventory_unit

      result = ResolveScan.call(organization: @org, query: unit.unit_identifier, store: @store)

      assert result.resolved?
      assert_equal unit.id, result.inventory_unit.id
      assert_equal @variant.id, result.variant.id
      assert_nil result.error
      assert_empty result.blockers
    end

    test "marks a reserved unit as unit_not_available" do
      unit = Inventory::CreateInventoryUnit.call(
        store: @store, product_variant: @variant, actor: @admin, acquisition_cost_cents: 900
      ).inventory_unit
      day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = OpenSession.call(
        business_day: day, store: @store, pos_device: pos_devices(:register_1),
        cash_drawer: cash_drawers(:drawer_1), opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      txn = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, inventory_unit: unit, quantity: 1, actor: @admin)
      unit.reload
      assert_equal "reserved", unit.status

      result = ResolveScan.call(organization: @org, query: unit.unit_identifier, store: @store)

      assert result.resolved?
      assert_includes result.blockers, "unit_not_available"
    end
  end
end
