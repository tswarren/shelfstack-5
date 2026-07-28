# frozen_string_literal: true

require "application_system_test_case"

# Browser coverage: first-step unlinked-return errors must remain visible inside
# turbo-frame#pos_overlay (Turbo does not honor response Turbo-Frame:_top).
class PosUnlinkedReturnOverlaySystemTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @reason = return_reasons(:defective)
    @admin = users(:admin)
    IdentifierSequence.ensure_defaults!
  end

  test "missing MAC and department estimate keeps error visible in start return overlay" do
    neutralize_unlinked_cost_basis!(@variant)
    sign_in_and_open_session!

    visit register_path
    assert_text "REGISTER READY"
    click_link "Start return"
    assert_selector "dialog[open]", wait: 5
    assert_text "Start return"

    within("dialog[open]") do
      assert_text "How is this return starting?"
      click_link "Begin unlinked return"
    end

    assert_selector "dialog[open]", wait: 5
    within("dialog[open]") do
      select "#{@variant.product.name} · #{@variant.sku}", from: "Product variant"
      select "External receipt", from: "Return source"
      click_button "Continue with product"
    end

    assert_selector "dialog[open]", wait: 5
    within("dialog[open]") do
      assert_text "Confirm item"
      click_button "Use this item"
    end

    within("dialog[open]") do
      assert_text "Quantity & price"
      fill_in "Refund unit price", with: format("%.2f", @variant.regular_price_cents / 100.0)
      click_button "Continue"
    end

    within("dialog[open]") do
      assert_text "Reason & disposition"
      select @reason.name, from: "Reason"
      select "Return to stock", from: "Disposition"
      click_button "Continue"
    end

    within("dialog[open]") do
      assert_text "Review"
      click_button "Start with unlinked return"
    end

    assert_selector "dialog[open]", wait: 5
    within("dialog[open]") do
      assert_selector "[role=alert]", text: /no inventory cost basis/i
      assert_button "Start with unlinked return"
      click_button "Close"
    end
    assert_no_selector "dialog[open]", wait: 5
    assert_current_path register_path, ignore_query: true
  end

  private

  def neutralize_unlinked_cost_basis!(variant)
    balance = StockBalance.find_by(store: @store, product_variant: variant)
    if balance
      balance.update!(
        moving_average_cost_cents: nil,
        inventory_value_cents: nil,
        cost_quality: "unknown"
      )
    end
    Department.where(organization_id: @store.organization_id)
      .update_all(default_cost_estimation_margin_bps: nil)
  end

  def sign_in_and_open_session!
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
  end
end
