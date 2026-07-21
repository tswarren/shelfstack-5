# frozen_string_literal: true

require "test_helper"

module Inventory
  class CreateInventoryUnitTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @variant = product_variants(:signed_book_standard)
      @quantity_variant = product_variants(:sample_book_standard)
      @user = users(:admin)
      @clerk = users(:clerk)
    end

    test "denies an actor without inventory.unit.manage" do
      result = CreateInventoryUnit.call(store: @store, product_variant: @variant, actor: @clerk)

      refute result.success?
      assert_equal "not permitted", result.error
      assert_nil result.inventory_unit
    end

    test "creates a unit with a generated 27 identifier and exact acquisition cost" do
      result = CreateInventoryUnit.call(
        store: @store, product_variant: @variant, actor: @user, acquisition_cost_cents: 1200
      )

      assert result.success?, result.error
      unit = result.inventory_unit
      assert unit.persisted?
      assert_equal "27", unit.unit_identifier[0, 2]
      assert_equal "available", unit.status
      assert_equal 1200, unit.acquisition_cost_cents
      assert AdministrativeAuditEvent.exists?(action: "inventory_unit.created", subject_type: "InventoryUnit", subject_id: unit.id)
    end

    test "second unit for the same variant gets a distinct identifier" do
      first = CreateInventoryUnit.call(store: @store, product_variant: @variant, actor: @user).inventory_unit
      second = CreateInventoryUnit.call(store: @store, product_variant: @variant, actor: @user).inventory_unit

      refute_equal first.unit_identifier, second.unit_identifier
    end

    test "rejects a quantity-tracked variant" do
      result = CreateInventoryUnit.call(store: @store, product_variant: @quantity_variant, actor: @user)

      refute result.success?
      assert_match(/individual inventory tracking/, result.error)
    end

    test "missing acquisition cost is recorded as unknown, not zero, at conversion" do
      unit = CreateInventoryUnit.call(store: @store, product_variant: @variant, actor: @user).inventory_unit

      assert_nil unit.acquisition_cost_cents
    end

    test "require_unit_manage_permission false allows a receiver without inventory.unit.manage" do
      result = CreateInventoryUnit.call(
        store: @store, product_variant: @variant, actor: @clerk, acquisition_cost_cents: 700,
        acquisition_source_type: "receipt_line", require_unit_manage_permission: false
      )

      assert result.success?, result.error
      assert_equal "receipt_line", result.inventory_unit.acquisition_source_type
    end
  end
end
