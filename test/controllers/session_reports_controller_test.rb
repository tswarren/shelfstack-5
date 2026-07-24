# frozen_string_literal: true

require "test_helper"

class SessionReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    post session_path, params: { username: "admin", password: "password123" }

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 1000, cashier: @admin, actor: @admin
    ).pos_session
  end

  test "session X shows masthead, live banner, settlement bridge, and cash build-up" do
    get session_x_report_pos_session_path(@session)
    assert_response :success
    assert_select ".report-badge--live", text: /Live/
    assert_match(/Live report/, response.body)
    assert_match(/Settlement bridge/, response.body)
    assert_match(/Stored-value activity/, response.body)
    assert_match(/Cash accountability/, response.body)
    assert_match(/Opening cash/, response.body)
    assert_match(/Activity counts/, response.body)
  end
end
