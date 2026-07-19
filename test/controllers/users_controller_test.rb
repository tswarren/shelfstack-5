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

  test "sets approval PIN on create and preserves it when blank on update" do
    post users_path, params: {
      user: {
        username: "approver",
        first_name: "App",
        last_name: "Rover",
        password: "password123",
        password_confirmation: "password123",
        pin: "2468",
        pin_confirmation: "2468",
        active: true
      }
    }

    user = User.find_by!(username: "approver")
    assert user.pin_configured?
    assert user.authenticate_pin("2468")

    patch user_path(user), params: {
      user: {
        first_name: "Approver",
        pin: "",
        pin_confirmation: ""
      }
    }
    assert_redirected_to user_path(user)
    assert user.reload.authenticate_pin("2468")
  end

  test "rejects non-digit approval PIN" do
    post users_path, params: {
      user: {
        username: "badpin",
        password: "password123",
        password_confirmation: "password123",
        pin: "12ab",
        pin_confirmation: "12ab",
        active: true
      }
    }

    assert_response :unprocessable_entity
    refute User.exists?(username: "badpin")
  end
end
