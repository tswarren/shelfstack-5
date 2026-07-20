# frozen_string_literal: true

require "test_helper"

class StoreSelectionsOpenTransactionTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)

    post session_path, params: { username: "admin", password: "password123" }

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @pos_session = Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @pos_session, actor: @admin).pos_transaction
  end

  test "cannot open store selection while an open transaction is active" do
    get new_store_selection_path
    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/switching stores/, flash[:alert])
  end

  test "cannot switch stores while an open transaction is active" do
    other = stores(:warehouse) rescue nil
    skip "second store fixture unavailable" unless other

    post store_selection_path, params: { store_id: other.id }
    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal @store.id, session[:store_id]
  end

  test "store selection is allowed after the transaction is suspended" do
    assert Pos::SuspendTransaction.call(pos_transaction: @transaction, actor: @admin).success?

    get new_store_selection_path
    # Admin has a single membership, so selection redirects home rather than
    # rendering the chooser — but must not bounce back to the open sale.
    assert_response :redirect
    assert_redirected_to root_path
  end
end
