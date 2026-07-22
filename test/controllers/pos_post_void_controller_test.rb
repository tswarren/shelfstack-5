# frozen_string_literal: true

require "test_helper"

class PosPostVoidControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)

    open_inventory(@variant, quantity: 3, unit_cost_cents: 400)
    post session_path, params: { username: "admin", password: "password123" }

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
    assert Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "ctl-sale"
    ).success?
  end

  test "post void form approve then submit" do
    get post_void_form_pos_transaction_path(@transaction)
    assert_response :success
    assert_select "input[type=submit][value='Approve post-void']"

    post approve_post_void_pos_transaction_path(@transaction), params: {
      post_void_reason: "cashier error",
      approver_username: "admin",
      approver_pin: "1234"
    }
    assert_redirected_to post_void_form_pos_transaction_path(@transaction)

    get post_void_form_pos_transaction_path(@transaction)
    assert_response :success
    assert_select "input[type=submit][value='Post-void transaction']"
    assert_select "input[name=approver_pin]", count: 0

    assert_difference -> { PosTransaction.where.not(reverses_pos_transaction_id: nil).count }, 1 do
      post post_void_pos_transaction_path(@transaction), params: {
        completion_idempotency_key: "ctl-pv-1"
      }
    end
    assert_response :redirect
    reversing = PosTransaction.find_by!(reverses_pos_transaction_id: @transaction.id)
    assert_redirected_to pos_transaction_path(reversing)
  end

  test "post void accepts nested card confirmation parameters" do
    card = tender_types(:card_standalone)
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
    assert Pos::AddCardTender.call(
      pos_transaction: txn, tender_type: card, amount_cents: net,
      authorization_code: "AUTH-CTL", actor: @admin
    ).success?
    assert Pos::CompleteTransaction.call(
      pos_transaction: txn, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ctl-card-sale"
    ).success?
    txn.reload
    card_tender = txn.pos_tenders.settled.find { |t| t.tender_type.tender_category == "card" }

    post approve_post_void_pos_transaction_path(txn), params: {
      post_void_reason: "card reverse",
      approver_username: "admin",
      approver_pin: "1234"
    }
    assert_redirected_to post_void_form_pos_transaction_path(txn)

    assert_difference -> { PosTransaction.where.not(reverses_pos_transaction_id: nil).count }, 1 do
      post post_void_pos_transaction_path(txn), params: {
        completion_idempotency_key: "ctl-pv-card",
        card_confirmations: {
          card_tender.id => {
            external_void_confirmed: "1",
            external_void_reference: "EXT-1",
            confirmation_note: "reversed on terminal"
          }
        }
      }
    end
    assert_response :redirect
    reversing = PosTransaction.find_by!(reverses_pos_transaction_id: txn.id)
    assert_redirected_to pos_transaction_path(reversing)
    reversing_tender = reversing.pos_tenders.find_by!(reverses_pos_tender_id: card_tender.id)
    assert_equal "EXT-1", reversing_tender.external_void_reference
  end

  private

  def open_inventory(variant, quantity:, unit_cost_cents:)
    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
      input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
    )
    assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
  end
end
