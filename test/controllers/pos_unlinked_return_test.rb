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

  test "return intent renders unlinked return form and creates a line" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    get pos_transaction_path(txn, intent: "return")
    assert_response :success
    assert_select "section[aria-label='Unlinked return']"
    assert_select "form#unlinked_return_form"

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
        confirm_cost_basis: "true"
      }
    end
    assert_redirected_to pos_transaction_path(txn, intent: "sale", focus_target: "scan")
    line = txn.pos_line_items.returns.last
    assert_equal "external_receipt", line.return_source
    assert_equal "current_configured_rules", line.tax_basis_snapshot
    assert_nil line.original_pos_line_item_id
  end
end
