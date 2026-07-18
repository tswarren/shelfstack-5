# frozen_string_literal: true

require "test_helper"

class CashDrawersControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "creates drawer and writes audit" do
    assert_difference([ "CashDrawer.count", "AdministrativeAuditEvent.count" ]) do
      post cash_drawers_path, params: {
        cash_drawer: { code: "DRW9", name: "Drawer 9", active: true }
      }
    end

    assert_redirected_to cash_drawers_path
    event = AdministrativeAuditEvent.order(:id).last
    assert_equal "drawer.created", event.action
    assert_equal "DRW9", event.metadata["code"]
  end

  test "denies clerk without drawer manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get cash_drawers_path
    assert_redirected_to root_path
  end
end
