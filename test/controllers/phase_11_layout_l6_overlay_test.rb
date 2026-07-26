# frozen_string_literal: true

require "test_helper"

class Phase11LayoutL6OverlayTest < ActionDispatch::IntegrationTest
  setup do
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
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
  end

  test "ready hosts product lookup overlay dialog without leaving the shell" do
    get register_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay"
    assert_select "dialog#pos-product-lookup"
    assert_select "dialog#pos-product-lookup [data-controller='record-picker']"
    assert_select "button[data-pos-overlay-id-param='pos-product-lookup']", text: "Product lookup"
    assert_select ".pos-shell"
  end
end
