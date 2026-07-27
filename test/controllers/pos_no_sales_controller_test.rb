# frozen_string_literal: true

require "test_helper"

class PosNoSalesControllerTest < ActionDispatch::IntegrationTest
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

  test "records no sale from register" do
    assert_difference -> { PosNoSaleEvent.count }, 1 do
      post register_no_sale_path, params: {
        reason: "Drawer check",
        idempotency_key: "ctrl-no-sale-1"
      }
    end
    assert_redirected_to register_path
    follow_redirect!
    assert_match(/No Sale recorded/i, flash[:notice].to_s)
  end

  test "overlay requires permission and cash-enabled session" do
    get pos_overlay_no_sale_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
  end
end
