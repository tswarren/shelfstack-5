# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "creates user and writes audit" do
    assert_difference([ "User.count", "AdministrativeAuditEvent.count" ]) do
      post users_path, params: {
        user: {
          username: "newhire",
          first_name: "New",
          last_name: "Hire",
          password: "password123",
          password_confirmation: "password123",
          active: true
        }
      }
    end

    user = User.find_by!(username: "newhire")
    assert_redirected_to user_path(user)
    event = AdministrativeAuditEvent.order(:id).last
    assert_equal "user.created", event.action
    assert_equal "newhire", event.metadata["username"]
  end

  test "index includes users without store memberships" do
    orphan = User.create!(
      username: "orphan",
      password: "password123",
      password_confirmation: "password123",
      active: true
    )

    get users_path
    assert_response :success
    assert_match orphan.username, response.body
  end

  test "show and edit resolve installation-global users without membership" do
    orphan = User.create!(
      username: "lonely",
      password: "password123",
      password_confirmation: "password123",
      active: true
    )

    get user_path(orphan)
    assert_response :success

    get edit_user_path(orphan)
    assert_response :success
  end

  test "denies clerk without user manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get new_user_path
    assert_redirected_to root_path
  end
end
