# frozen_string_literal: true

require "test_helper"

class PosCustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    @store = stores(:main_street)
    @admin = users(:admin)
    @customer = customers(:jordan_lee)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    sign_in_as(@admin, store: @store)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    @txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AttachCustomer.call(pos_transaction: @txn, customer: @customer, actor: @admin)
    @txn.reload
  end

  test "remove customer clears attachment via member :id route" do
    assert_equal @customer.id, @txn.customer_id

    post remove_customer_pos_transaction_path(@txn)
    assert_redirected_to pos_transaction_path(@txn)
    follow_redirect!
    assert_match(/Customer removed/i, response.body)
    assert_nil @txn.reload.customer_id
  end

  test "attach customer uses member :id route" do
    @txn.update!(customer: nil)

    post attach_customer_pos_transaction_path(@txn), params: { customer_id: @customer.id }
    assert_redirected_to pos_transaction_path(@txn)
    assert_equal @customer.id, @txn.reload.customer_id
  end

  test "attach form uses search-to-link customer record picker" do
    @txn.update!(customer: nil)

    get pos_transaction_path(@txn)
    assert_response :success
    assert_match "data-record-picker-record-type-value=\"customer\"", response.body
    assert_no_match(/<select[^>]*name="customer_id"/, response.body)
  end

  private

  def sign_in_as(user, store:)
    post session_path, params: { username: user.username, password: "password123" }
    post store_selection_path, params: { store_id: store.id } if session[:store_id].blank?
  end
end
