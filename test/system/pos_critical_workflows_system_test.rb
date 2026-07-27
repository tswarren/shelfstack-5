# frozen_string_literal: true

require "application_system_test_case"

# Phase 4g-3: critical register workflows (scan→complete, suspend/recall,
# unpaid Complete gated by readiness, keyboard complete).
class PosCriticalWorkflowsSystemTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @department = departments(:books_new)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
  end

  test "scan add tender and complete finishes the sale" do
    open_register_with_transaction!

    visit pos_transaction_path(@transaction)
    assert_text "Scan or search"

    within("section[aria-label='Scan or search']") do
      fill_in "Scan or search", with: @variant.sku
      click_button "Add"
    end
    assert_text(/available quantity is negative|Line added/i, wait: 5)
    assert_equal 1, @transaction.reload.pos_line_items.pending.count

    enter_tender_and_cash!(Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents)

    click_button "Complete transaction"
    assert_text(/Transaction complete|completed/i, wait: 5)
    assert @transaction.reload.completed?
  end

  test "suspend leave recall and complete resumes the sale" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )

    visit pos_transaction_path(@transaction)
    find("summary", text: "More").click
    click_button "Suspend"
    assert_text "Transaction suspended"
    assert_current_path register_path
    assert @transaction.reload.suspended?

    visit register_path
    assert_selector "section[aria-label='Suspended work']"
    accept_confirm do
      click_button "Recall"
    end
    assert_text "Transaction recalled"
    assert @transaction.reload.open?

    enter_tender_and_cash!(Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents)
    click_button "Complete transaction"
    assert_text(/Transaction complete|completed/i, wait: 5)
    assert @transaction.reload.completed?
  end

  test "unpaid transaction does not expose Complete until settled" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )

    visit pos_transaction_path(@transaction)
    assert_no_button "Complete transaction"
    assert_link "Tender", href: /\/tender/

    enter_tender_and_cash!(Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents)
    assert_text "Tender recorded"

    click_button "Complete transaction"
    assert_text(/Transaction complete|completed/i, wait: 5)
    assert @transaction.reload.completed?
  end

  test "keyboard Ctrl+Enter completes a settled transaction" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )
    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: @transaction, tender_type: tender_types(:cash),
      amount_tendered_cents: net, actor: @admin
    )

    visit tender_pos_transaction_path(@transaction)
    assert_button "Complete transaction"

    # Focus body (common tender posture) and dispatch from that element so
    # event.target matches real keydown targeting — not the document root.
    page.execute_script(<<~JS)
      const body = document.body
      body.setAttribute("tabindex", "-1")
      body.focus()
      body.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", code: "Enter", ctrlKey: true, bubbles: true })
      )
    JS
    assert_text(/Transaction complete|completed/i, wait: 5)
    assert @transaction.reload.completed?
  end

  test "Ctrl+Enter does not progress while an overlay dialog is open" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )
    line = @transaction.pos_line_items.pending.last

    visit pos_transaction_path(@transaction, selected_line_id: line.id, focus_target: "line_actions")
    assert_link "Tender", href: /\/tender/
    assert_equal "transaction", find(".pos-shell")["data-pos-presentation"]

    click_link "Discount"
    assert_selector "dialog[open]", wait: 5
    assert_text "Line discount"

    # Focus a field inside the open dialog, then Ctrl+Enter must not advance Tender.
    page.execute_script(<<~JS)
      const field = document.querySelector("dialog[open] input, dialog[open] select, dialog[open] textarea")
      field?.focus()
      field?.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", code: "Enter", ctrlKey: true, bubbles: true })
      )
    JS

    assert_selector "dialog[open]"
    assert_equal "transaction", find(".pos-shell")["data-pos-presentation"]
    assert_current_path pos_transaction_path(@transaction), ignore_query: true
    refute @transaction.reload.completed?
  end

  private

  def enter_tender_and_cash!(net_cents)
    click_link "Tender", href: /\/tender/
    fill_in "Amount tendered", with: format("%.2f", net_cents / 100.0)
    click_button "Add cash tender"
    assert_text "Tender recorded"
  end

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
