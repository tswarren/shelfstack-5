# frozen_string_literal: true

require "test_helper"

# Gate 11E — Recovery + release hardening. Journey matrix is conditional on
# Gate D Should scope: gift-receipt / SV-slip document journeys are not required
# unless those Should items ship.
class Phase11eRecoveryReleaseTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @card = tender_types(:card_standalone)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
  end

  test "void_required always restores Recovery and blocks commercial editing" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddOpenRingLine.call(
      pos_transaction: txn, department: departments(:books_new), unit_price_cents: 1000, actor: @admin
    )
    mismatch = Pos::AddCardTender.call(
      pos_transaction: txn, tender_type: @card, amount_cents: 1500,
      authorization_code: "11E-VOID", actor: @admin
    )
    assert mismatch.requires_void_confirmation?

    get pos_transaction_path(txn)
    assert_response :success
    assert_select "body[data-pos-presentation=recovery]"
    assert_select ".pos-recovery-panel", text: /void_required/
    assert_select ".pos-presentation-status", text: /Recovery/
    assert_select "section[aria-label='Scan or search']", count: 0

    before = txn.reload.attributes.slice("status", "updated_at")
    get tender_pos_transaction_path(txn)
    assert_response :success
    assert_select "body[data-pos-presentation=recovery]"
    assert_equal before, txn.reload.attributes.slice("status", "updated_at")
  end

  test "keyboard contract markers remain on register workspace" do
    post session_path, params: { username: "admin", password: "password123" }
    get register_path
    assert_response :success
    assert_select "[data-controller~=pos-register]"
    assert_select "[data-pos-register-target=scanInput]"
    assert_select ".pos-live-region[aria-live=polite]"
  end
end
