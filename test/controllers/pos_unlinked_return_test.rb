# frozen_string_literal: true

require "test_helper"

class PosUnlinkedReturnTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @reason = return_reasons(:defective)
    pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
  end

  test "return entry intent opens overlay while scan bar stays on transaction" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    get pos_transaction_path(txn)
    assert_response :success
    assert_select "section[aria-label='Scan or search']"
    assert_select "a[href=?][data-turbo-frame=pos_overlay]",
                  pos_overlay_start_return_path(pos_transaction_id: txn.id), text: "Return"
    assert_select "section[aria-label='Unlinked return']", count: 0

    get pos_overlay_start_return_path(pos_transaction_id: txn.id)
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_select "form#txn_unlinked_return_form", count: 0
    assert_select "a", text: "Begin unlinked return"

    get pos_overlay_start_return_path(pos_transaction_id: txn.id, return_mode: "unlinked")
    assert_response :success
    assert_select "form#txn_unlinked_return_form[action=?]", pos_transaction_pos_return_lines_path(txn)

    assert_difference -> { txn.pos_line_items.returns.count }, 1 do
      post pos_transaction_pos_return_lines_path(txn), params: {
        mode: "unlinked",
        return_source: "external_receipt",
        return_reason_id: @reason.id,
        return_disposition: "return_to_stock",
        product_variant_id: @variant.id,
        unit_price_cents: format("%.2f", @variant.regular_price_cents / 100.0),
        quantity: 1,
        tax_basis: "current_configured_rules",
        confirm_cost_basis: "true",
        reviewed_cost_unit_cents: StockBalance.find_by!(store: @store, product_variant: @variant).moving_average_cost_cents,
        reviewed_cost_source: "store_stock_balance_mac"
      }
    end
    assert_redirected_to pos_transaction_path(txn, intent: "sale", focus_target: "scan")
  end

  test "wizard continue advances past identify even when posted step is stale" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    post pos_transaction_pos_return_lines_path(txn), params: {
      mode: "unlinked",
      unlinked_step: "identify",
      product_variant_id: @variant.id,
      return_source: "external_receipt",
      wizard_continue: "1"
    }
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_match(/Step 2 of 5 — Confirm item/, response.body)
    assert_select "input[type=hidden][name=unlinked_step][value=confirm]"
  end

  test "open-ring wizard button advances to department step" do
    post session_path, params: { username: "admin", password: "password123" }

    post register_start_unlinked_return_path, params: {
      mode: "unlinked",
      unlinked_step: "identify",
      wizard_open_ring: "1"
    }
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_match(/Department/i, response.body)
    assert_select "input[type=hidden][name=unlinked_step][value=department]"
    assert_select "input[type=hidden][name=open_ring][value='1']"
  end

  test "open-ring quantity step renders without a product variant" do
    post session_path, params: { username: "admin", password: "password123" }
    department = departments(:books_new)

    post register_start_unlinked_return_path, params: {
      mode: "unlinked",
      unlinked_step: "department",
      open_ring: "1",
      department_id: department.id,
      return_source: "no_receipt",
      wizard_continue: "1"
    }
    assert_response :success
    assert_match(/Quantity &amp; price|Quantity & price/, response.body)
    assert_select "input[type=hidden][name=unlinked_step][value=quantity]"
  end

  test "successful unlinked add from overlay forces a full Turbo visit" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    mac = StockBalance.find_by!(store: @store, product_variant: @variant).moving_average_cost_cents

    assert_difference -> { txn.pos_line_items.returns.count }, 1 do
      post pos_transaction_pos_return_lines_path(txn),
           headers: { "Turbo-Frame" => "pos_overlay" },
           params: {
             mode: "unlinked",
             return_source: "external_receipt",
             return_reason_id: @reason.id,
             return_disposition: "return_to_stock",
             product_variant_id: @variant.id,
             unit_price_cents: format("%.2f", @variant.regular_price_cents / 100.0),
             quantity: 1,
             tax_basis: "current_configured_rules",
             confirm_cost_basis: "true",
             reviewed_cost_unit_cents: mac,
             reviewed_cost_source: "store_stock_balance_mac",
             return_mode: "unlinked"
           }
    end
    assert_response :success
    assert_match(/Turbo\.visit/, response.body)
    assert_match(%r{pos_transactions/#{txn.id}}, response.body)
  end

  test "unlinked inventory return without confirm renders cost review" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    assert_no_difference -> { txn.pos_line_items.returns.count } do
      post pos_transaction_pos_return_lines_path(txn), params: {
        mode: "unlinked",
        return_source: "external_receipt",
        return_reason_id: @reason.id,
        return_disposition: "return_to_stock",
        product_variant_id: @variant.id,
        unit_price_cents: format("%.2f", @variant.regular_price_cents / 100.0),
        quantity: 1,
        tax_basis: "current_configured_rules"
      }
    end
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_select "form#txn_unlinked_return_cost_confirm_form"
    assert_select "input[name=approver_pin]", count: 0
    assert_select "input[name=reviewed_cost_unit_cents]", count: 1
    assert_match(/Proposed inventory cost/i, response.body)
  end

  test "cost review does not embed unused approval fields for no_receipt" do
    post session_path, params: { username: "admin", password: "password123" }
    membership = StoreMembership.find_by!(user: @admin, store: @store)
    membership.update!(maximum_no_receipt_return_cents: 10_000_00)
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    post pos_transaction_pos_return_lines_path(txn), params: {
      mode: "unlinked",
      return_source: "no_receipt",
      return_reason_id: @reason.id,
      return_disposition: "return_to_stock",
      product_variant_id: @variant.id,
      unit_price_cents: format("%.2f", @variant.regular_price_cents / 100.0),
      quantity: 1,
      tax_basis: "current_configured_rules",
      unlinked_step: "review"
    }
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_select "input[name=approver_pin]", count: 0
    assert_select "input[name=approver_username]", count: 0
  end

  test "missing inventory cost basis re-renders overlay with visible error" do
    post session_path, params: { username: "admin", password: "password123" }
    neutralize_unlinked_cost_basis!(@variant)
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    assert_no_difference -> { txn.pos_line_items.returns.count } do
      post pos_transaction_pos_return_lines_path(txn), params: {
        mode: "unlinked",
        return_source: "external_receipt",
        return_reason_id: @reason.id,
        return_disposition: "return_to_stock",
        product_variant_id: @variant.id,
        unit_price_cents: format("%.2f", @variant.regular_price_cents / 100.0),
        quantity: 1,
        tax_basis: "current_configured_rules",
        unlinked_step: "review"
      }
    end
    assert_response :unprocessable_entity
    assert_nil response.headers["Turbo-Frame"]
    assert_select "turbo-frame#pos_overlay dialog"
    assert_select "[role=alert]", text: /no inventory cost basis/i
    assert_select "form#txn_unlinked_return_form"
    assert_select "input[type=hidden][name=product_variant_id][value=?]", @variant.id.to_s
    assert_select "input[type=hidden][name=return_disposition][value=return_to_stock]"
  end

  test "ready unlinked return requires pos.transaction.open when no open transaction exists" do
    post session_path, params: { username: "admin", password: "password123" }
    cashier = create_limited_cashier(%w[pos.access pos.return.create pos.return.no_receipt])
    membership = StoreMembership.find_by!(user: cashier, store: @store)
    membership.update!(maximum_no_receipt_return_cents: 10_000_00)

    device_b = PosDevice.find_or_create_by!(store: @store, code: "REG-UNLINKED") do |device|
      device.name = "Register Unlinked"
      device.device_type = "register"
      device.active = true
    end
    day = @session.business_day
    cashier_session = Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: device_b,
      cashier: cashier, actor: @admin
    )
    assert cashier_session.success?, cashier_session.error

    delete session_path
    post session_path, params: { username: cashier.username, password: "password123" }

    assert_no_difference -> { PosTransaction.count } do
      assert_no_difference -> { PosLineItem.count } do
        post register_start_unlinked_return_path, params: {
          return_source: "no_receipt",
          return_reason_id: @reason.id,
          return_disposition: "non_inventory",
          product_variant_id: @variant.id,
          unit_price_cents: "10.00",
          quantity: 1,
          tax_basis: "current_configured_rules"
        }
      end
    end
    assert_redirected_to root_path
    assert_match(/not authorized/i, flash[:alert])
  end

  private

  def neutralize_unlinked_cost_basis!(variant)
    balance = StockBalance.find_by(store: @store, product_variant: variant)
    if balance
      balance.update!(
        moving_average_cost_cents: nil,
        inventory_value_cents: nil,
        cost_quality: "unknown"
      )
    end
    Department.where(organization_id: @store.organization_id)
      .update_all(default_cost_estimation_margin_bps: nil)
  end

  def create_limited_cashier(permission_codes)
    username = "cashier_#{SecureRandom.hex(2)}"
    user = User.create!(
      username: username,
      user_number: rand(10_000..99_999),
      first_name: "Cash", last_name: "Ier",
      password: "password123",
      active: true, default_store: @store
    )
    role = Role.create!(
      organization: @store.organization,
      code: "role_#{username}",
      name: "Role #{username}",
      active: true
    )
    permission_codes.each do |code|
      RolePermission.create!(role: role, permission: Permission.find_by!(code: code))
    end
    StoreMembership.create!(user: user, store: @store, role: role, active: true)
    user
  end
end
