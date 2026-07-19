# frozen_string_literal: true

require "test_helper"

class PosCompletionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)

    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: @variant, position: 0, quantity_delta: 5,
      input_unit_cost_cents: 500, input_cost_method: "explicit", input_cost_quality: "actual"
    )
    Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store)

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    @line = Pos::AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
    @net_total = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
  end

  test "cashier records a cash tender and completes the transaction end to end" do
    post session_path, params: { username: "admin", password: "password123" }

    post pos_transaction_pos_tenders_path(@transaction),
         params: { tender_type_id: @cash.id, amount_tendered_cents: @net_total }
    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal 1, @transaction.pos_tenders.unresolved.count

    post complete_pos_transaction_path(@transaction), params: { completion_idempotency_key: "ctrl-key-1" }

    @transaction.reload
    assert_redirected_to pos_transaction_path(@transaction)
    assert @transaction.completed?
    assert @transaction.receipt_number.present?
    assert_equal "Transaction completed.", flash[:notice]

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_match @transaction.receipt_number, response.body
  end

  test "clerk without pos.transaction.complete permission is denied" do
    post session_path, params: { username: "clerk", password: "password123" }

    post complete_pos_transaction_path(@transaction), params: { completion_idempotency_key: "ctrl-key-2" }

    assert_redirected_to root_path
    assert_match(/not authorized/, flash[:alert])
    refute @transaction.reload.completed?
  end

  test "clerk without pos.tender.cash permission cannot record a cash tender" do
    post session_path, params: { username: "clerk", password: "password123" }

    post pos_transaction_pos_tenders_path(@transaction),
         params: { tender_type_id: @cash.id, amount_tendered_cents: @net_total }

    assert_redirected_to root_path
    assert_equal 0, @transaction.pos_tenders.count
  end
end
