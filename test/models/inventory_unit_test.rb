# frozen_string_literal: true

require "test_helper"

class InventoryUnitTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @variant = product_variants(:signed_book_standard)
    @quantity_variant = product_variants(:sample_book_standard)
    @user = users(:admin)
  end

  test "valid unit with a generated 27 identifier" do
    unit = InventoryUnit.new(
      store: @store, product_variant: @variant, unit_identifier: "2700000000014",
      status: "available", acquired_at: Time.current, created_by_user: @user
    )
    assert unit.valid?, unit.errors.full_messages.to_sentence
  end

  test "rejects a quantity-tracked variant" do
    unit = InventoryUnit.new(
      store: @store, product_variant: @quantity_variant, unit_identifier: "2700000000014",
      status: "available", acquired_at: Time.current, created_by_user: @user
    )
    refute unit.valid?
    assert_includes unit.errors[:product_variant], "must use individual inventory tracking"
  end

  test "rejects an identifier outside the generated 27 namespace" do
    unit = InventoryUnit.new(
      store: @store, product_variant: @variant, unit_identifier: "2800000000011",
      status: "available", acquired_at: Time.current, created_by_user: @user
    )
    refute unit.valid?
    assert_includes unit.errors[:unit_identifier], "must be a valid generated namespace 27 EAN-13"
  end

  test "rejects a negative acquisition cost" do
    unit = InventoryUnit.new(
      store: @store, product_variant: @variant, unit_identifier: "2700000000014",
      status: "available", acquired_at: Time.current, created_by_user: @user, acquisition_cost_cents: -1
    )
    refute unit.valid?
    assert_includes unit.errors[:acquisition_cost_cents], "must be greater than or equal to 0"
  end
end
