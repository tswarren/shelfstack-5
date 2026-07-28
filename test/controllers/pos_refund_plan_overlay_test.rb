# frozen_string_literal: true

require "test_helper"

class PosRefundPlanOverlayTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)
    @reason = return_reasons(:defective)
    pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )

    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    sale_line = Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
    Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin, completion_idempotency_key: "refund-plan-sale"
    )
    sale_line.reload

    @return_txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: @return_txn,
      original_pos_line_item: sale_line,
      quantity: 1,
      return_reason: @reason,
      return_disposition: "return_to_stock",
      actor: @admin
    ).success?
  end

  test "review edit plan overlay loads for open return tender" do
    post session_path, params: { username: "admin", password: "password123" }

    get pos_overlay_refund_plan_path(pos_transaction_id: @return_txn.id)
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_match(/Proposed refund plan|Refund due/, response.body)
    assert_select "form[action=?]", accept_refund_plan_pos_transaction_path(@return_txn)
    assert_select "input[name^=plan_rows]", minimum: 1
  end

  test "tender workspace links to refund plan overlay" do
    post session_path, params: { username: "admin", password: "password123" }

    get tender_pos_transaction_path(@return_txn)
    assert_response :success
    assert_select "a[href=?][data-turbo-frame=pos_overlay]",
                  pos_overlay_refund_plan_path(pos_transaction_id: @return_txn.id),
                  text: "Review / edit plan"
  end

  test "accepting an edited plan omits unchecked destinations" do
    post session_path, params: { username: "admin", password: "password123" }
    plan = Pos::ProposeRefundPlan.call(pos_transaction: @return_txn)
    assert_equal 1, plan.rows.size
    row = plan.rows.first

    post accept_refund_plan_pos_transaction_path(@return_txn), params: {
      plan_rows: {
        "0" => {
          included: "0",
          destination: row.destination,
          original_pos_tender_id: row.original_pos_tender&.id,
          amount_cents: format("%.2f", row.amount_cents / 100.0)
        }
      }
    }
    assert_redirected_to tender_pos_transaction_path(@return_txn)
    assert_match(/at least one/i, flash[:alert].to_s)
    assert_equal 0, @return_txn.pos_tenders.unresolved.where(direction: "refunded").count

    post accept_refund_plan_pos_transaction_path(@return_txn), params: {
      plan_rows: {
        "0" => {
          included: "1",
          destination: row.destination,
          original_pos_tender_id: row.original_pos_tender&.id,
          amount_cents: format("%.2f", row.amount_cents / 100.0)
        }
      }
    }
    assert_redirected_to tender_pos_transaction_path(@return_txn)
    refunds = @return_txn.pos_tenders.unresolved.where(direction: "refunded")
    assert_equal 1, refunds.count, flash[:alert]
    assert_equal row.amount_cents, refunds.first.amount_cents
  end
end
