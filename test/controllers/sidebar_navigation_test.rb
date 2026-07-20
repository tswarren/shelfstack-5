# frozen_string_literal: true

require "test_helper"

class SidebarNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @clerk = users(:clerk)
    @store = stores(:main_street)
  end

  test "admin home renders sidebar with permitted navigation without permission query explosion" do
    sign_in_as(@admin, store: @store)

    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if payload[:name] == "SCHEMA"
      next if sql.match?(/\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      queries << sql
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get root_path
    end

    assert_response :success
    assert_select "aside.app-sidebar"
    assert_select "aside.app-sidebar a", text: "Products"
    assert_select "aside.app-sidebar a", text: "Register"
    assert_select "a.skip-link", text: "Skip to main content"

    permission_lookups = queries.count { |sql| sql.match?(/FROM ["`]?permissions["`]?/i) }
    role_permission_lookups = queries.count { |sql| sql.match?(/role_permissions/i) }
    # Preload should be a small constant number of queries, not one per nav item.
    assert_operator permission_lookups + role_permission_lookups, :<=, 4,
                    "expected sidebar permission preload, got #{permission_lookups + role_permission_lookups} related queries"
  end

  test "clerk does not see unauthorized administration navigation" do
    membership = store_memberships(:clerk_main_street)
    skip "clerk membership fixture missing" unless membership

    sign_in_as(@clerk, store: @store)
    get root_path
    assert_response :success
    assert_select "aside.app-sidebar a", text: "Users", count: 0
    assert_select "aside.app-sidebar a", text: "Roles", count: 0
  end

  test "unauthorized direct URL remains denied" do
    sign_in_as(@clerk, store: @store)
    get users_path
    assert_redirected_to root_path
  end

  private

  def sign_in_as(user, store:)
    post session_path, params: { username: user.username, password: "password123" }
    post store_selection_path, params: { store_id: store.id } if session[:store_id].blank?
  end
end
