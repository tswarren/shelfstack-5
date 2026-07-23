# frozen_string_literal: true

require "application_system_test_case"

# Phase 4g-3: critical register workflows (scan→complete, suspend/recall,
# failed-completion recovery, keyboard complete). Does not duplicate completed-
# screen Enter / <summary> coverage in PosReviewFixesSystemTest.
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
    assert_text "Scan / search"

    within("section[aria-label='Scan or search']") do
      fill_in "Scan or search", with: @variant.sku
      click_button "Add line"
    end
    assert_text(/available quantity is negative|Line added/i, wait: 5)
    assert_equal 1, @transaction.reload.pos_line_items.pending.count

    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    fill_in "Amount tendered", with: format("%.2f", net / 100.0)
    click_button "Add cash tender"
    assert_text "Tender recorded"

    click_button "Complete transaction"
    assert_text(/completed/i)
    assert @transaction.reload.completed?
  end

  test "suspend leave recall and complete resumes the sale" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )

    visit pos_transaction_path(@transaction)
    click_button "Suspend"
    assert_text "Transaction suspended"
    assert_current_path register_path
    assert @transaction.reload.suspended?

    visit register_path
    assert_text "Suspended transactions"
    within("details", text: /Suspended transactions/) do
      accept_confirm do
        click_button "Recall"
      end
    end
    assert_text "Transaction recalled"
    assert @transaction.reload.open?

    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    fill_in "Amount tendered", with: format("%.2f", net / 100.0)
    click_button "Add cash tender"
    click_button "Complete transaction"
    assert_text(/completed/i)
    assert @transaction.reload.completed?
  end

  test "failed completion recovers after tender is corrected" do
    open_register_with_transaction!
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )

    visit pos_transaction_path(@transaction)
    click_button "Complete transaction"
    assert_text(/tenders .* do not settle|settle/i)
    assert @transaction.reload.open?

    net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
    fill_in "Amount tendered", with: format("%.2f", net / 100.0)
    click_button "Add cash tender"
    assert_text "Tender recorded"

    click_button "Complete transaction"
    assert_text(/completed/i)
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

    visit pos_transaction_path(@transaction)
    assert_button "Complete transaction"

    # With a pending tender the scan field is locked; Ctrl+Enter is handled on
    # the register workspace (see pos_register_controller).
    page.execute_script(<<~JS)
      document.querySelector(".pos-workspace").dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", code: "Enter", ctrlKey: true, bubbles: true })
      )
    JS
    assert_text(/completed/i)
    assert @transaction.reload.completed?
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
