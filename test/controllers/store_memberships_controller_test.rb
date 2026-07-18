# frozen_string_literal: true

require "test_helper"

class StoreMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "creates membership and writes audit with role metadata" do
    user = User.create!(
      username: "tempuser",
      password: "password123",
      password_confirmation: "password123",
      active: true
    )

    assert_difference([ "StoreMembership.count", "AdministrativeAuditEvent.count" ]) do
      post store_memberships_path, params: {
        store_membership: {
          user_id: user.id,
          role_id: roles(:associate).id,
          active: true,
          starts_on: Date.current
        }
      }
    end

    assert_redirected_to store_memberships_path
    event = AdministrativeAuditEvent.order(:id).last
    assert_equal "membership.created", event.action
    assert_equal user.id, event.metadata["user_id"]
    assert_equal roles(:associate).id, event.metadata["role_id"]
  end

  test "update ignores attempted user_id rewrite" do
    membership = store_memberships(:clerk_main_street)
    original_user_id = membership.user_id

    patch store_membership_path(membership), params: {
      store_membership: {
        user_id: users(:admin).id,
        role_id: roles(:associate).id,
        active: true
      }
    }

    assert_redirected_to store_memberships_path
    assert_equal original_user_id, membership.reload.user_id
  end

  test "denies clerk without membership manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get store_memberships_path
    assert_redirected_to root_path
  end
end
