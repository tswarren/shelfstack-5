# frozen_string_literal: true

require "test_helper"

class PosLineItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @product_request = product_requests(:open_customer_request)
    @product_request.update!(product_variant: @variant)

    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: @variant, position: 0, quantity_delta: 5,
      input_unit_cost_cents: 500, input_cost_method: "explicit", input_cost_quality: "actual"
    )
    Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store)

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    session = Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction

    post session_path, params: { username: "admin", password: "password123" }
  end

  test "adding a line with only a customer request selected uses the request variant" do
    assert_difference -> { @transaction.pos_line_items.count }, 1 do
      post pos_transaction_pos_line_items_path(@transaction), params: {
        product_request_id: @product_request.id,
        quantity: 1
      }
    end

    assert_redirected_to pos_transaction_path(@transaction)
    line = @transaction.pos_line_items.order(:id).last
    assert_equal @variant.id, line.product_variant_id
    assert_equal @product_request.id, line.product_request_id
  end

  test "blank scan without a customer request still reports not found" do
    post pos_transaction_pos_line_items_path(@transaction), params: { quantity: 1 }

    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/No product found/i, flash[:alert])
  end
end
