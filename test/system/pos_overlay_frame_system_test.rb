# frozen_string_literal: true

require "application_system_test_case"

class PosOverlayFrameSystemTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @admin = users(:admin)
  end

  test "product lookup loads only the overlay frame and leave-POS uses top navigation" do
    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    )

    visit register_path
    assert_text(/Scan merchandise|Scan to start/i)
    assert_no_selector "dialog[open]"

    click_link "Product lookup"
    assert_selector "turbo-frame#pos_overlay dialog", wait: 5
    assert_selector "dialog[open]", wait: 5
    assert_text "Product variant"
    assert_current_path register_path

    within "dialog[open]" do
      click_button "Close"
    end
    assert_no_selector "dialog[open]", wait: 3
    assert_equal "Product lookup", page.evaluate_script("document.activeElement?.textContent?.trim()")

    within(".pos-register-header") { click_link "Store Operations" }
    assert_current_path register_store_operations_path
    assert_text "Close Session"
    assert_text "Close business day"
  end
end
