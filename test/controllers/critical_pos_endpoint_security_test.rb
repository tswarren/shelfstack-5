# frozen_string_literal: true

require "test_helper"

# Phase 4g-2: critical POS/session/day/reservation/stock authorization and scoping.
class CriticalPosEndpointSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @warehouse = stores(:warehouse)
    @admin = users(:admin)
    @clerk = users(:clerk)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)
    @department = departments(:books_new)

    pos_open_inventory(
      store: @store, variant: @variant, quantity: 5, unit_cost_cents: 500, actor: @admin
    )
    @day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin, opening_cash_cents: 1000
    )
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    @line = Pos::AddLine.call(
      pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin
    ).pos_line_item
  end

  test "clerk without pos.transaction.cancel is denied cancel" do
    post session_path, params: { username: "clerk", password: "password123" }
    post cancel_pos_transaction_path(@transaction)
    assert_redirected_to root_path
    assert @transaction.reload.open?
  end

  test "admin can cancel an open transaction" do
    post session_path, params: { username: "admin", password: "password123" }
    post cancel_pos_transaction_path(@transaction), params: { reason: "test cancel" }
    assert_redirected_to register_path
    assert @transaction.reload.cancelled?
  end

  test "cross-store transaction id is not found" do
    post session_path, params: { username: "admin", password: "password123" }
    foreign_day = Pos::OpenBusinessDay.call(store: @warehouse, actor: @admin).business_day
    foreign_device = PosDevice.create!(
      store: @warehouse, code: "WH1", name: "Warehouse 1", active: true
    )
    foreign_session = Pos::OpenSession.call(
      business_day: foreign_day, store: @warehouse, pos_device: foreign_device,
      cashier: @admin, actor: @admin
    ).pos_session
    foreign_txn = Pos::OpenTransaction.call(pos_session: foreign_session, actor: @admin).pos_transaction

    get pos_transaction_path(foreign_txn)
    assert_response :not_found
  end

  test "clerk without cash movement permission is denied" do
    post session_path, params: { username: "clerk", password: "password123" }
    type = cash_movement_type!
    assert_no_difference "PosCashMovement.count" do
      post pos_session_pos_cash_movements_path(@session), params: {
        cash_movement_type_id: type.id, amount_cents: 500, reason: "float"
      }
    end
    assert_redirected_to root_path
  end

  test "admin can create a cash movement on the current session" do
    post session_path, params: { username: "admin", password: "password123" }
    type = cash_movement_type!
    assert_difference "PosCashMovement.count", 1 do
      post pos_session_pos_cash_movements_path(@session), params: {
        cash_movement_type_id: type.id, amount_cents: "5.00", reason: "float"
      }
    end
    assert_response :redirect
  end

  test "stock balances hide cost without inventory.cost.view" do
    balance = StockBalance.find_by!(store: @store, product_variant: @variant)
    post session_path, params: { username: "clerk", password: "password123" }
    # Clerk may lack stock.view — grant only stock.view without cost.view
    RolePermission.find_or_create_by!(
      role: roles(:associate), permission: Permission.find_by!(code: "inventory.stock.view")
    )
    get stock_balance_path(balance)
    assert_response :success
    assert_no_match(/Moving average|Inventory value|unit cost/i, response.body)
  end

  test "admin with cost.view sees stock cost fields" do
    balance = StockBalance.find_by!(store: @store, product_variant: @variant)
    post session_path, params: { username: "admin", password: "password123" }
    get stock_balance_path(balance)
    assert_response :success
    assert_match(/Inventory value|Moving average|Last known/i, response.body)
  end

  test "reservation release requires inventory.reservation.release" do
    post session_path, params: { username: "clerk", password: "password123" }
    reservation = InventoryReservation.find_by!(source_type: "pos_line_item", source_id: @line.id)
    post release_inventory_reservation_path(reservation)
    assert_redirected_to root_path
    assert_equal "active", reservation.reload.status
  end

  test "business day close is denied without permission" do
    post session_path, params: { username: "clerk", password: "password123" }
    post close_business_day_path(@day)
    assert_redirected_to root_path
    assert @day.reload.open?
  end

  private

  def cash_movement_type!
    CashMovementType.find_or_create_by!(organization: @store.organization, code: "paid_in") do |t|
      t.name = "Paid in"
      t.direction = "cash_in"
      t.active = true
      t.requires_approval = false
      t.requires_reference = false
    end
  end
end
