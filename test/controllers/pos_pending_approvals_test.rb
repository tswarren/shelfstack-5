# frozen_string_literal: true

require "test_helper"

class PosPendingApprovalsTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
  end

  test "price override requiring approval stages interrupt without applying" do
    post session_path, params: { username: "admin", password: "password123" }
    membership = StoreMembership.find_by!(user: @admin, store: @store)
    membership.update!(maximum_price_override_rate: 0.05)

    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    line = Pos::AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item
    original = line.unit_price_cents
    requested = (original * 0.5).to_i

    patch override_price_pos_transaction_pos_line_item_path(txn, line), params: {
      requested_unit_price_cents: format("%.2f", requested / 100.0),
      reason: "customer request"
    }

    line.reload
    assert_equal original, line.unit_price_cents
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match(/Approval required|Approve and continue/i, response.body)
    assert_select "input[name=approver_pin]", count: 1
    assert_select "form[action=?]", pos_pending_approval_path
  end

  test "cancel clears pending approval" do
    post session_path, params: { username: "admin", password: "password123" }
    Pos::PendingApprovalAction.store(
      session,
      action: "price_override",
      fingerprint: "x",
      payload: { "pos_transaction_id" => 1 },
      presentation: Pos::PendingApprovalAction::Presentation.new(
        title: "Approval required",
        action_summary: "Test",
        boundary: "Bound",
        material_values: "Values",
        effect: "Effect"
      )
    )
    delete pos_pending_approval_path
    assert_redirected_to register_path
    assert_nil Pos::PendingApprovalAction.load(session)
  end
end
