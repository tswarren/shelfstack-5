# frozen_string_literal: true

require "test_helper"

class PosPostVoidControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)

    open_inventory(@variant, quantity: 3, unit_cost_cents: 400)
    post session_path, params: { username: "admin", password: "password123" }

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
    assert Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "ctl-sale"
    ).success?
  end

  test "post void form and submit" do
    get post_void_form_pos_transaction_path(@transaction)
    assert_response :success

    assert_difference -> { PosTransaction.where.not(reverses_pos_transaction_id: nil).count }, 1 do
      post post_void_pos_transaction_path(@transaction), params: {
        post_void_reason: "cashier error",
        approver_username: "admin",
        approver_pin: "1234",
        completion_idempotency_key: "ctl-pv-1"
      }
    end
    assert_response :redirect
    reversing = PosTransaction.find_by!(reverses_pos_transaction_id: @transaction.id)
    assert_redirected_to pos_transaction_path(reversing)
  end

  private

  def open_inventory(variant, quantity:, unit_cost_cents:)
    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
      input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
    )
    assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
  end
end
