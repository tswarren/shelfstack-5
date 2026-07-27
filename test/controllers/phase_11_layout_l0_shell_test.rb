# frozen_string_literal: true

require "test_helper"

class Phase11LayoutL0ShellTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "ready register uses dedicated shell regions without back-office page header" do
    get register_path
    assert_response :success
    assert_select ".pos-shell"
    assert_select ".pos-register-header"
    assert_select "#pos-primary"
    assert_select "#pos-summary"
    assert_select "#pos-commands"
    assert_select "turbo-frame#pos_workspace[target=_top]"
    assert_select "turbo-frame#pos_overlay"
    assert_select ".page-header", count: 0
    assert_select ".app-header", count: 0
    assert_select ".pos-register-header__brand-link", text: /ShelfStack/
  end
end
