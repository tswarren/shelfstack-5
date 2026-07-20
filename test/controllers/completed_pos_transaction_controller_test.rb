# frozen_string_literal: true

require "test_helper"

# Phase 4g-1/2: completed transaction mutation endpoints are rejected.
class CompletedPosTransactionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)

    pos_open_inventory(
      store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin
    )
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    @transaction, @line, _net = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "immut-web"
    )

    post session_path, params: { username: "admin", password: "password123" }
  end

  test "web endpoints reject mutating a completed transaction" do
    patch pos_transaction_pos_line_item_path(@transaction, @line), params: { quantity: 2 }
    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/not open|cannot|completed|editable|pending|linked return/i, flash[:alert].to_s)

    delete pos_transaction_pos_line_item_path(@transaction, @line), params: { reason: "x" }
    assert_redirected_to pos_transaction_path(@transaction)

    post suspend_pos_transaction_path(@transaction)
    assert_redirected_to pos_transaction_path(@transaction)

    post cancel_pos_transaction_path(@transaction)
    assert_redirected_to pos_transaction_path(@transaction)

    assert_equal 1, @line.reload.quantity
    assert @transaction.reload.completed?
  end
end
