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

  test "register Ready omits day session tables and offers Store Operations" do
    post session_path, params: { username: "admin", password: "password123" }
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

    get register_path
    assert_response :success
    assert_select ".pos-shell"
    assert_select "a[href=?]", register_store_operations_path, text: "Store Operations"
    assert_select "a", text: "Day X", count: 0
    assert_select "a", text: "Close business day", count: 0
    refute_match(/Net sales/, response.body)
    refute_match(/cash variance/i, response.body)

    get register_store_operations_path
    assert_response :success
    assert_select "a[href=?]", close_form_pos_session_path(PosSession.open_sessions.order(:id).last),
                  text: "Close Session"
    assert_select "a", text: "Day X"
    assert_select "a", text: "Close business day"
    assert_select "a", text: "Session X"
  end

  test "admin can open day/session, add lines, suspend, and recall" do
    post session_path, params: { username: "admin", password: "password123" }

    post business_days_path, params: { business_day: { reporting_date: Date.current } }
    assert_redirected_to register_path
    business_day = BusinessDay.order(:id).last
    assert_equal "open", business_day.status

    post pos_sessions_path, params: {
      pos_session: {
        business_day_id: business_day.id,
        pos_device_id: @device.id,
        cash_drawer_id: @drawer.id,
        opening_cash_cents: 0
      }
    }
    assert_redirected_to register_path
    session = PosSession.order(:id).last
    assert_equal "open", session.status

    open_inventory(@variant, quantity: 5, unit_cost_cents: 500)
    assert_no_difference "PosTransaction.count" do
      post pos_transactions_path
      assert_redirected_to register_path
    end

    assert_difference "PosTransaction.count", 1 do
      post register_scan_to_start_path, params: { query: @variant.sku, quantity: 2 }
    end
    transaction = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(transaction)
    assert_equal 1, transaction.pos_line_items.pending.count
    assert_equal 2, transaction.pos_line_items.pending.first.quantity

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

  test "scan to start from ready opens transaction and adds line" do
    post session_path, params: { username: "admin", password: "password123" }

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

    assert_difference -> { PosTransaction.count }, 1 do
      post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    end
    transaction = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(transaction)
    assert_equal 1, transaction.pos_line_items.pending.count
  end

  test "failed ready scan does not create empty transaction" do
    post session_path, params: { username: "admin", password: "password123" }
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

    assert_no_difference -> { PosTransaction.count } do
      post register_scan_to_start_path, params: { query: "NO-MATCH-SKU-XYZ", quantity: 1 }
    end
    assert_redirected_to register_path
  end

  test "ambiguous ready scan stays on Ready; explicit variant starts atomically" do
    products(:sample_book).update!(alternate_identifier: "SHAREDALT01")
    products(:upc_product).update!(alternate_identifier: "SHAREDALT01")
    open_inventory(product_variants(:sample_book_standard), quantity: 3, unit_cost_cents: 500)

    post session_path, params: { username: "admin", password: "password123" }
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

    assert_no_difference -> { PosTransaction.count } do
      post register_scan_to_start_path, params: { query: "SHAREDALT01", quantity: 2 }
    end
    assert_redirected_to register_path
    assert_equal "ambiguous", flash[:scan_outcome]
    assert_equal "SHAREDALT01", flash[:scan_query]

    assert_no_difference -> { PosTransaction.count } do
      post pos_transactions_path, params: { query: "SHAREDALT01", quantity: 2 }
    end
    assert_redirected_to register_path

    variant = product_variants(:sample_book_standard)
    assert_difference -> { PosTransaction.count }, 1 do
      post register_scan_to_start_path, params: { product_variant_id: variant.id, quantity: 2 }
    end
    transaction = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(transaction)
    line = transaction.pos_line_items.pending.last
    assert_equal variant, line.product_variant
    assert_equal 2, line.quantity
  end

  test "receipt lookup finds completed receipt" do
    post session_path, params: { username: "admin", password: "password123" }
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

    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    transaction = PosTransaction.order(:id).last
    cash = tender_types(:cash)
    net = Pos::RecalculateTransaction.call(pos_transaction: transaction).net_total_cents
    post pos_transaction_pos_tenders_path(transaction), params: {
      tender_type_id: cash.id, amount_tendered_cents: net
    }
    post complete_pos_transaction_path(transaction), params: { completion_idempotency_key: SecureRandom.uuid }
    transaction.reload
    assert transaction.completed?

    post register_lookup_receipt_path, params: { receipt_number: transaction.receipt_number }
    assert_redirected_to pos_transaction_path(transaction)
  end

  test "transaction show does not rewrite tax rows" do
    post session_path, params: { username: "admin", password: "password123" }
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

    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    transaction = PosTransaction.order(:id).last

    tax_ids = PosLineItemTax.where(pos_line_item_id: transaction.pos_line_items.select(:id)).order(:id).pluck(:id, :amount_cents)
    get pos_transaction_path(transaction)
    assert_response :success
    assert_select "[aria-label=Readiness]"
    assert_equal tax_ids,
                 PosLineItemTax.where(pos_line_item_id: transaction.pos_line_items.select(:id)).order(:id).pluck(:id, :amount_cents)
  end

  test "tender path forces tender presentation and primary CTA" do
    post session_path, params: { username: "admin", password: "password123" }
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

    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    transaction = PosTransaction.order(:id).last

    get tender_pos_transaction_path(transaction)
    assert_response :success
    assert_select "[data-pos-presentation='tender']"
    assert_select "#pos-primary [aria-label='Payment']"
  end

  test "completed next transaction link does not create a record" do
    post session_path, params: { username: "admin", password: "password123" }
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

    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    transaction = PosTransaction.order(:id).last
    cash = tender_types(:cash)
    net = Pos::RecalculateTransaction.call(pos_transaction: transaction).net_total_cents
    post pos_transaction_pos_tenders_path(transaction), params: {
      tender_type_id: cash.id, amount_tendered_cents: net
    }
    post complete_pos_transaction_path(transaction), params: { completion_idempotency_key: SecureRandom.uuid }
    transaction.reload

    assert_no_difference -> { PosTransaction.count } do
      get pos_transaction_path(transaction)
      assert_response :success
      assert_select "a[href=?][data-turbo-frame=_top]", register_path, text: "Next transaction"
      get register_path
      assert_response :success
      assert_select "input.button-primary[value=?]", "Scan to start"
    end
  end

  test "failed and ambiguous ready scans leave no transaction" do
    post session_path, params: { username: "admin", password: "password123" }
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

    assert_no_difference "PosTransaction.count" do
      post register_scan_to_start_path, params: { query: "NO-SUCH-SKU-ZZZ", quantity: 1 }
      assert_redirected_to register_path
    end

    get register_path
    assert_response :success
    assert_no_match(/New transaction/, response.body)
    assert_no_match(/Open transaction to resolve/, response.body)
  end

  test "register and transaction show expose server presentation without mutating txn" do
    post session_path, params: { username: "admin", password: "password123" }
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

    get register_path
    assert_response :success
    assert_select "body.layout-pos[data-pos-presentation=ready]"
    assert_select ".pos-presentation-status", text: /Ready/

    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    transaction = PosTransaction.order(:id).last
    before = transaction.reload.attributes.slice("status", "updated_at", "net_total_cents")

    get pos_transaction_path(transaction)
    assert_response :success
    assert_select "body.layout-pos[data-pos-presentation=transaction]"
    assert_select ".pos-presentation-status", text: /Transaction/
    assert_equal before, transaction.reload.attributes.slice("status", "updated_at", "net_total_cents")

    get tender_pos_transaction_path(transaction)
    assert_response :success
    assert_select "body.layout-pos[data-pos-presentation=tender]"
    assert_equal before, transaction.reload.attributes.slice("status", "updated_at", "net_total_cents")
  end

  private

  def open_inventory(variant, quantity:, unit_cost_cents:)
    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: users(:admin)
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
      input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
    )
    assert Inventory::PostAdjustment.call(adjustment: opening, actor: users(:admin), store: @store).success?
  end
end
