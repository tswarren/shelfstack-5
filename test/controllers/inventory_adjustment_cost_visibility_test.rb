# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentCostVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @adjustment = InventoryAdjustment.create!(
      store: @store,
      kind: "opening_inventory",
      status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
      created_by_user: users(:admin),
      note: nil
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: @adjustment,
      product_variant: product_variants(:sample_book_standard),
      position: 0,
      quantity_delta: 1,
      input_unit_cost_cents: 999,
      input_cost_method: "explicit",
      input_cost_quality: "actual"
    )
  end

  test "stock viewer without cost or create permission cannot see draft costs" do
    RolePermission.where(role: roles(:associate), permission: permissions(:inventory_stock_view)).first_or_create!
    # Grant only stock.view to associate for this test.
    associate = roles(:associate)
    Permission.find_each do |permission|
      next unless permission.code == "inventory.stock.view"

      RolePermission.find_or_create_by!(role: associate, permission: permission)
    end

    post session_path, params: { username: "clerk", password: "password123" }
    get inventory_adjustment_path(@adjustment)
    assert_response :success
    assert_no_match(/\$9\.99/, response.body)
  end
end
