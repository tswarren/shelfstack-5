# frozen_string_literal: true

require "test_helper"

# Phase 4f UX baseline (PR2): operational POS layout, currency-mask cents
# contract, actionable scan resolution, and sign-out guarding.
class PosUxBaselineTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @department = departments(:books_new)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    post session_path, params: { username: "admin", password: "password123" }
  end

  test "the register renders on the operational pos layout" do
    get register_path

    assert_response :success
    assert_select "body.layout-pos"
    assert_select ".workspace-landing"
  end

  test "a cash tender posts integer cents exactly as the currency mask submits them" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 1999, actor: @admin
    )

    # Integer cents still accepted (tests / non-UI clients).
    post pos_transaction_pos_tenders_path(@transaction),
         params: { tender_type_id: @cash.id, amount_tendered_cents: 1250 }

    assert_redirected_to pos_transaction_path(@transaction)
    tender = @transaction.pos_tenders.order(:created_at).last
    assert_equal 1250, tender.amount_cents
  end

  test "a cash tender parses a decimal-dollar amount from the named currency field" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 1999, actor: @admin
    )

    post pos_transaction_pos_tenders_path(@transaction),
         params: { tender_type_id: @cash.id, amount_tendered_cents: "12.50" }

    assert_redirected_to pos_transaction_path(@transaction)
    tender = @transaction.pos_tenders.order(:created_at).last
    assert_equal 1250, tender.amount_cents
  end

  test "invalid tender amount is rejected without recording a tender" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )

    assert_no_difference -> { @transaction.pos_tenders.count } do
      post pos_transaction_pos_tenders_path(@transaction),
           params: { tender_type_id: @cash.id, amount_tendered_cents: "abc" }
    end
    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/amount/i, flash[:alert])
  end

  test "the transaction show page uses the two-panel workspace" do
    get pos_transaction_path(@transaction)

    assert_response :success
    assert_select ".pos-workspace .pos-sale-panel"
    assert_select ".pos-workspace .pos-payment-panel"
    assert_select "[data-controller='pos-register']"
    assert_select "input.input-currency"
  end

  test "an ambiguous scan surfaces an actionable resolution region and selection adds a line" do
    products(:sample_book).update!(alternate_identifier: "SHAREDALT01")
    products(:upc_product).update!(alternate_identifier: "SHAREDALT01")

    post pos_transaction_pos_line_items_path(@transaction), params: { query: "SHAREDALT01", quantity: 3 }
    assert_redirected_to pos_transaction_path(@transaction)

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select ".pos-scan-resolution"
    assert_match "The Illustrated Man", response.body
    assert_match "UPC Sample", response.body
    assert_select ".pos-scan-resolution input[name=quantity][value='3']"

    assert_difference -> { @transaction.pos_line_items.pending.count }, 1 do
      post pos_transaction_pos_line_items_path(@transaction),
           params: { product_variant_id: @variant.id, quantity: 3 }
    end
    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal 3, @transaction.pos_line_items.pending.last.quantity
  end

  test "a failed scan preserves the query and marks scan_outcome failed" do
    post pos_transaction_pos_line_items_path(@transaction), params: { query: "ZZZNOMATCH999" }
    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal "failed", flash[:scan_outcome]
    assert_equal "ZZZNOMATCH999", flash[:scan_query]

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select "input#scan_query[value='ZZZNOMATCH999']"
  end

  test "sign-out is blocked while the cashier controls an open transaction" do
    delete session_path

    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/complete, suspend, or cancel/i, flash[:alert])

    # Still authenticated: the register remains reachable.
    get register_path
    assert_response :success
  end

  test "sign-out succeeds once the open transaction is suspended" do
    post suspend_pos_transaction_path(@transaction)
    assert @transaction.reload.suspended?

    delete session_path
    assert_redirected_to new_session_path
  end

  test "register shows one primary CTA and POS header links to Main workspace" do
    post suspend_pos_transaction_path(@transaction)

    get register_path
    assert_response :success
    assert_select ".workspace-primary"
    assert_select ".workspace-primary input.button-primary[value=?]", "Scan to start"
    assert_select ".workspace-primary .button-outline", text: "New transaction"
    assert_select "a", text: "Main workspace"
    assert_select "a[href=?]", root_path, text: "Main workspace"
  end

  test "open-ring fields appear in department price quantity description order" do
    get pos_transaction_path(@transaction, intent: "open_ring")
    assert_response :success

    start = response.body.index("Open-ring line")
    assert start, "expected open-ring panel"
    segment = response.body[start..]
    dept_at = segment.index("Department")
    price_at = segment.index("open_ring_unit_price_cents")
    qty_at = segment.index('name="quantity"')
    desc_at = segment.index("Description (optional)")

    assert dept_at && price_at && qty_at && desc_at
    assert dept_at < price_at
    assert price_at < qty_at
    assert qty_at < desc_at
  end

  test "open-ring department options keep hierarchy order after filtering postable" do
    get pos_transaction_path(@transaction, intent: "open_ring")
    assert_response :success

    start = response.body.index("Open-ring line")
    segment = response.body[start..]
    books_new = departments(:books_new)
    unconfigured = departments(:unconfigured_tax_department)
    books_label = ApplicationController.helpers.hierarchy_path_label(books_new)
    unconfigured_label = ApplicationController.helpers.hierarchy_path_label(unconfigured)
    books_at = segment.index(books_label)
    unconfigured_at = segment.index(unconfigured_label)

    assert books_at, "expected #{books_label.inspect} in open-ring select"
    assert unconfigured_at, "expected #{unconfigured_label.inspect} in open-ring select"
    assert_operator books_at, :<, unconfigured_at,
                    "postable children should follow full-tree order (Books child before dept 800)"
  end

  test "completed transaction shows change due and back to register without print" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 1000, actor: @admin
    )
    Pos::AddCashTender.call(
      pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 2000, actor: @admin
    )
    Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ux-complete-change"
    )

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select ".pos-completed-summary"
    assert_match "Change due", response.body
    assert_select "a", text: "Next transaction"
    assert_no_match(/Print Receipt/i, response.body)
  end

  test "receipt lookup loads returnable lines for selection" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )
    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ux-sale-for-return"
    )
    receipt = @transaction.reload.receipt_number

    return_txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    post lookup_pos_transaction_pos_return_lines_path(return_txn), params: { receipt_number: receipt }
    assert_redirected_to pos_transaction_path(return_txn, intent: "return")

    get pos_transaction_path(return_txn, intent: "return")
    assert_response :success
    assert_match(/Receipt #{Regexp.escape(receipt)}/, response.body)
    assert_select "input[name=original_pos_line_item_id]", count: 1
    assert_no_match(/Original line ID/i, response.body)
  end

  test "linked return lines hide quantity update and reject crafted quantity patches" do
    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
      created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: @variant, position: 0,
      quantity_delta: 2, input_unit_cost_cents: 500, input_cost_method: "explicit",
      input_cost_quality: "actual"
    )
    assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?

    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    sale_line = Pos::AddLine.call(
      pos_transaction: sale, product_variant: @variant, quantity: 2, actor: @admin
    ).pos_line_item
    sale_net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin
    )
    Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ux-return-qty-sale"
    )
    sale_line.reload

    return_txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    return_line = Pos::AddLinkedReturnLine.call(
      pos_transaction: return_txn, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:defective), return_disposition: "return_to_stock",
      actor: @admin
    ).pos_line_item

    get pos_transaction_path(return_txn)
    assert_response :success
    assert_select "form.pos-inline-form[action=?]", pos_transaction_pos_line_item_path(return_txn, return_line), count: 0
    assert_select "input[type=submit][value=Update]", count: 0

    patch pos_transaction_pos_line_item_path(return_txn, return_line), params: { quantity: 2 }

    assert_redirected_to pos_transaction_path(return_txn)
    assert_match(/linked return quantity cannot be edited/i, flash[:alert])
    assert_equal 1, return_line.reload.quantity
    assert_equal 0, InventoryReservation.active.where(
      source_type: "pos_line_item", source_id: return_line.id
    ).count
  end

  test "operational forms render on the pos layout with currency masks" do
    get new_business_day_path
    assert_response :success
    assert_select "body.layout-pos"

    get new_pos_session_path(business_day_id: @day.id)
    assert_response :success
    assert_select "body.layout-pos"
    assert_select "input.input-currency"

    get close_form_pos_session_path(@session)
    assert_response :success
    assert_select "body.layout-pos"
    assert_select "input.input-currency"
    assert_match "Cash received", response.body
    assert_match "Change given", response.body
    assert_match "Cash refunded", response.body
    assert_match "Expected cash", response.body
  end

  test "closing a cash session formats variance with helper money formatting" do
    Pos::CancelTransaction.call(pos_transaction: @transaction, actor: @admin)

    post close_pos_session_path(@session), params: { counted_cash_cents: "1.00" }

    assert_redirected_to register_path
    assert_match(/Session closed\. Variance:/, flash[:notice].to_s)
    assert_match(/\$/, flash[:notice].to_s)
  end

  test "entry intents are filtered by permission and forbidden intent falls back to sale" do
    cashier = create_limited_cashier(%w[
      pos.access pos.transaction.open pos.line.remove
    ])

    delete session_path
    post session_path, params: { username: cashier.username, password: "password123" }

    get pos_transaction_path(@transaction, intent: "return")
    assert_response :success
    assert_select "[aria-label='Entry intent'] a", text: "Sale"
    assert_select "[aria-label='Entry intent'] a", text: "Open ring"
    assert_select "[aria-label='Entry intent'] a", text: "Return", count: 0
    assert_select "[aria-label='Entry intent'] a", text: "Stored value", count: 0
    assert_select "[aria-label='Entry intent'] a[aria-current=true]", text: "Sale"
    assert_select "section[aria-label='Linked return']", count: 0
  end

  test "completed receipt start linked return seeds return lookup on open transaction" do
    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    Pos::AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    complete = Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ux-start-linked-return"
    )
    assert complete.success?, complete.error
    @transaction.reload
    assert @transaction.completed?
    assert @transaction.receipt_number.present?

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select "form[action=?]", start_linked_return_pos_transaction_path(@transaction)

    assert_difference -> { PosTransaction.open_transactions.count }, 1 do
      post start_linked_return_pos_transaction_path(@transaction)
    end
    open_txn = PosTransaction.open_transactions.order(:id).last
    assert_redirected_to pos_transaction_path(open_txn, intent: "return")

    get pos_transaction_path(open_txn, intent: "return")
    assert_response :success
    assert_match(/Receipt #{Regexp.escape(@transaction.receipt_number)}/, response.body)
    assert_select "input[name=original_pos_line_item_id]", count: 1
  end

  test "start linked return requires pos.transaction.open when no open transaction exists" do
    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    Pos::AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    complete = Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ux-start-return-no-open-perm"
    )
    assert complete.success?, complete.error
    @transaction.reload

    device_b = PosDevice.find_or_create_by!(store: @store, code: "REG2") do |device|
      device.name = "Register 2"
      device.device_type = "register"
      device.active = true
    end
    cashier = create_limited_cashier(%w[pos.access pos.return.create])
    cashier_session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: device_b,
      cashier: cashier, actor: @admin
    )
    assert cashier_session.success?, cashier_session.error

    delete session_path
    post session_path, params: { username: cashier.username, password: "password123" }

    assert_no_difference -> { PosTransaction.open_transactions.count } do
      post start_linked_return_pos_transaction_path(@transaction)
    end
    assert_redirected_to root_path
    assert_match(/not authorized/i, flash[:alert])
  end

  test "completed receipt detail shows historical line discount and tax cents" do
    open_inventory(@variant, quantity: 2, unit_cost_cents: 500)
    line = Pos::AddLine.call(
      pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin
    ).pos_line_item
    discount = Pos::ApplyDiscount.call(
      pos_transaction: @transaction, scope: "line", pos_line_item: line,
      method: "fixed_amount", amount_cents: 150, actor: @admin
    )
    assert discount.success?, discount.error
    Pos::RecalculateTransaction.call(pos_transaction: @transaction)
    line.reload
    discount_cents = line.discount_amount_cents
    tax_cents = line.tax_amount_cents
    assert discount_cents.positive?
    assert tax_cents.positive?

    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    complete = Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ux-completed-snapshot-detail"
    )
    assert complete.success?, complete.error
    @transaction.reload
    line.reload
    assert_equal discount_cents, line.discount_amount_cents
    assert_equal tax_cents, line.tax_amount_cents

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select ".pos-completed-workspace"
    # Expanded transaction detail must retain historical discount/tax (not $0.00).
    body = response.body
    detail_start = body.index("Transaction detail")
    assert detail_start, "expected transaction detail section"
    detail = body[detail_start..]
    assert_includes detail, format("$%.2f", discount_cents / 100.0)
    assert_includes detail, format("$%.2f", tax_cents / 100.0)
  end

  private

  def open_inventory(variant, quantity:, unit_cost_cents:)
    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
      created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: variant, position: 0,
      quantity_delta: quantity, input_unit_cost_cents: unit_cost_cents,
      input_cost_method: "explicit", input_cost_quality: "actual"
    )
    assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
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
