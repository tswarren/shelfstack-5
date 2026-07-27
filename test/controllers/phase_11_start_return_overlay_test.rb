# frozen_string_literal: true

require "test_helper"

class Phase11StartReturnOverlayTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @reason = return_reasons(:defective)
    pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)

    post session_path, params: { username: "admin", password: "password123" }
    membership = StoreMembership.find_by!(user: @admin, store: @store)
    membership.update!(maximum_no_receipt_return_cents: 10_000_00)
    post business_days_path, params: { business_day: { reporting_date: Date.current } }
    business_day = BusinessDay.order(:id).last
    post pos_sessions_path, params: {
      pos_session: {
        business_day_id: business_day.id,
        pos_device_id: @device.id,
        cash_drawer_id: @drawer.id,
        opening_cash_cents: 0
      }
    }
  end

  test "ready start return opens start_return overlay with linked and unlinked paths" do
    get register_path
    assert_response :success
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_start_return_path, text: "Start return"

    get pos_overlay_start_return_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_select "form[action=?]", register_lookup_receipt_path
    assert_select "form#ready_unlinked_return_form[action=?]", register_start_unlinked_return_path
    assert_select "select[name=return_source] option[value=no_receipt]"
  end

  test "start unlinked return from ready creates first-valid-work transaction" do
    assert_difference -> { PosTransaction.count }, 1 do
      post register_start_unlinked_return_path, params: {
        return_source: "no_receipt",
        return_reason_id: @reason.id,
        return_disposition: "return_to_stock",
        product_variant_id: @variant.id,
        unit_price_cents: format("%.2f", @variant.regular_price_cents / 100.0),
        quantity: 1,
        tax_basis: "current_configured_rules",
        confirm_cost_basis: "true"
      }
    end
    txn = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(txn, intent: "return")
    assert_equal 1, txn.pos_line_items.returns.count
    assert_equal "no_receipt", txn.pos_line_items.returns.last.return_source
  end
end
