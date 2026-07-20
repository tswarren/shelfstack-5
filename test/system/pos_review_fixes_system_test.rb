# frozen_string_literal: true

require "application_system_test_case"

# Browser coverage for UX baseline review fixes (store-switch, currency,
# scan preserve, tender/complete, keyboard disclosure).
class PosReviewFixesSystemTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @department = departments(:books_new)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
  end

  test "store switch is blocked while an open transaction is active" do
    open_register_with_transaction!

    visit register_path
    assert_text "Register"
    assert_no_link "Switch store"

    visit new_store_selection_path
    assert_current_path pos_transaction_path(@transaction)
    assert_text(/complete, suspend, or cancel/i)
  end

  test "currency field submits a typed decimal amount without relying on hidden cents" do
    open_register_with_transaction!

    visit pos_transaction_path(@transaction)
    assert_text "Scan / search"
    find("summary", text: "Open-ring line").click
    select @department.name, from: "Department"
    fill_in "Price", with: "7.25"
    click_button "Add open-ring line"

    assert_text "Open-ring line added"
    line = @transaction.pos_line_items.pending.find_by(line_kind: "open_ring")
    assert_equal 725, line.unit_price_cents
  end

  test "failed scan preserves the query and successful add clears the scan field" do
    open_register_with_transaction!

    visit pos_transaction_path(@transaction)
    assert_text "Scan / search"

    within("section[aria-label='Scan or search']") do
      fill_in "Scan or search", with: "ZZZNOMATCH999"
      click_button "Add line"
    end
    assert_field "Scan or search", with: "ZZZNOMATCH999"

    # Capybara fill_in/click_button does not reliably replace a server-prefilled
    # scan value after a failed Turbo PRG; set and submit via the live DOM.
    page.execute_script(
      "document.getElementById('scan_query').value = arguments[0];" \
      "document.querySelector('section[aria-label=\"Scan or search\"] form').requestSubmit()",
      @variant.sku
    )

    assert_text(/available quantity is negative|Line added/i, wait: 5)
    assert_equal 1, @transaction.reload.pos_line_items.pending.count
    assert_field "Scan or search", with: ""
  end

  test "ambiguous scan resolution keeps the entered quantity" do
    products(:sample_book).update!(alternate_identifier: "SHAREDALT01")
    products(:upc_product).update!(alternate_identifier: "SHAREDALT01")
    open_register_with_transaction!

    visit pos_transaction_path(@transaction)
    assert_text "Scan / search"

    within("section[aria-label='Scan or search']") do
      fill_in "Scan or search", with: "SHAREDALT01"
      fill_in "Qty", with: "4"
      click_button "Add line"
    end

    assert_text "Multiple products matched"
    within(".pos-scan-resolution") do
      assert_selector "input[name=quantity][value='4']", visible: :all
      within("li", text: "The Illustrated Man") do
        click_button "Add Standard"
      end
    end

    assert_text "The Illustrated Man"
    line = @transaction.reload.pos_line_items.pending.order(:id).last
    assert_not_nil line
    assert_equal 4, line.quantity
  end

  test "tender and complete path records cash and finishes the sale" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )

    visit pos_transaction_path(@transaction)
    assert_text "Amount tendered"
    # Cover tax so tenders settle the net total.
    fill_in "Amount tendered", with: "5.65"
    click_button "Add cash tender"

    assert_text "Tender recorded"
    click_button "Complete transaction"
    assert_text(/completed/i)
    assert @transaction.reload.completed?
  end

  test "Enter on the completed summary returns to the register" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )
    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: @transaction, tender_type: tender_types(:cash),
      amount_tendered_cents: net, actor: @admin
    )
    Pos::CompleteTransaction.call(
      pos_transaction: @transaction, pos_session: @session, actor: @admin,
      completion_idempotency_key: "system-complete-enter"
    )

    visit pos_transaction_path(@transaction)
    assert_text "Transaction complete"
    assert_text "Back to register"

    # Focus is on the workspace (not the link); document-level Enter should navigate.
    page.execute_script("document.activeElement && document.activeElement.blur()")
    find(".pos-completed-workspace").send_keys(:return)

    assert_current_path register_path
  end

  test "keyboard path opens a secondary POS disclosure" do
    open_register_with_transaction!

    visit pos_transaction_path(@transaction)
    assert_text "Transaction-wide discount"
    details = find("details", text: /Transaction-wide discount/)
    details.find("summary").send_keys(:return)
    assert details[:open].present?
  end

  private

  def open_register_with_transaction!
    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
  end
end
