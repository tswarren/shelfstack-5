# frozen_string_literal: true

require "test_helper"

class RegisterFlowTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @department = departments(:books_new)
    @variant = product_variants(:sample_book_standard)
  end

  test "admin can open day/session, add lines, suspend, and recall" do
    post session_path, params: { username: "admin", password: "password123" }

    post business_days_path, params: { business_day: { reporting_date: Date.current } }
    assert_redirected_to register_path
    business_day = BusinessDay.order(:id).last
    assert_equal "open", business_day.status

    post pos_sessions_path, params: {
      pos_session: { business_day_id: business_day.id, pos_device_id: @device.id, cash_drawer_id: @drawer.id }
    }
    assert_redirected_to register_path
    session = PosSession.order(:id).last
    assert_equal "open", session.status

    post pos_transactions_path
    transaction = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(transaction)

    post pos_transaction_pos_line_items_path(transaction), params: { query: @variant.sku, quantity: 2 }
    assert_redirected_to pos_transaction_path(transaction)
    assert_equal 1, transaction.pos_line_items.pending.count

    post pos_transaction_pos_line_items_path(transaction), params: {
      kind: "open_ring", department_id: @department.id, unit_price_cents: 500, quantity: 1
    }
    assert_equal 2, transaction.pos_line_items.pending.count
    open_ring_line = transaction.pos_line_items.pending.find_by(line_kind: "open_ring")
    assert_equal @department.name, open_ring_line.description_snapshot

    line = transaction.pos_line_items.pending.find_by(line_kind: "product")
    delete pos_transaction_pos_line_item_path(transaction, line), params: { reason: "test" }
    assert_equal 1, transaction.pos_line_items.pending.count
    assert_equal "removed", line.reload.status

    post suspend_pos_transaction_path(transaction)
    assert_redirected_to register_path
    assert transaction.reload.suspended?

    post recall_pos_transaction_path(transaction)
    assert_redirected_to pos_transaction_path(transaction)
    assert transaction.reload.open?
  end

  test "clerk without pos.business_day.open permission is denied" do
    post session_path, params: { username: "clerk", password: "password123" }

    post business_days_path, params: { business_day: { reporting_date: Date.current } }
    assert_redirected_to root_path
    assert_equal 0, BusinessDay.count
  end
end
