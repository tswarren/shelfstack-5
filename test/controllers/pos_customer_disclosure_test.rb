# frozen_string_literal: true

require "test_helper"

class PosCustomerDisclosureTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)
    @customer = customers(:jordan_lee)

    pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    @transaction, _line, _net = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "cust-disclose"
    )
    @transaction.update!(customer: @customer)
  end

  test "completed transaction hides customer identity from POS-only users" do
    user = pos_only_user

    post session_path, params: { username: user.username, password: "password123" }
    get pos_transaction_path(@transaction)

    assert_response :success
    assert_match(/Customer attached/i, response.body)
    assert_no_match(/Jordan Lee/, response.body)
    assert_no_match(@customer.customer_number, response.body)
  end

  test "completed transaction shows customer identity with lookup permission" do
    post session_path, params: { username: "clerk", password: "password123" }
    get pos_transaction_path(@transaction)

    assert_response :success
    assert_match(/Jordan Lee/, response.body)
    assert_match(@customer.customer_number, response.body)
  end

  private

  def pos_only_user
    user = User.create!(
      username: "pos_only_#{SecureRandom.hex(2)}",
      user_number: rand(10_000..99_999),
      first_name: "Pos", last_name: "Only",
      password: "password123",
      active: true, default_store: @store
    )
    role = Role.create!(
      organization: @store.organization,
      code: "pos_only_#{user.username}",
      name: "POS only",
      active: true
    )
    RolePermission.create!(role: role, permission: Permission.find_by!(code: "pos.access"))
    StoreMembership.create!(user: user, store: @store, role: role, active: true)
    user
  end
end
