# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signs in with normalized username and sets store from membership" do
    post session_path, params: { username: "ADMIN", password: "password123" }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_match "admin", response.body
    assert_match "Main Street", response.body
  end

  test "rejects locked user" do
    users(:admin).update!(locked_at: Time.current)
    post session_path, params: { username: "admin", password: "password123" }
    assert_redirected_to new_session_path
    assert_equal "Your account cannot sign in.", flash[:alert]
  end

  test "increments failed attempts without setting locked_at" do
    post session_path, params: { username: "admin", password: "wrong" }
    assert_redirected_to new_session_path
    users(:admin).reload
    assert_equal 1, users(:admin).failed_login_attempts
    assert_nil users(:admin).locked_at
  end

  test "default store without membership does not grant access" do
    users(:clerk).update!(default_store: stores(:warehouse))
    post session_path, params: { username: "clerk", password: "password123" }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "Main Street", response.body
    assert_no_match "Warehouse", response.body
  end

  test "user with multiple memberships is sent to store selection" do
    StoreMembership.create!(
      user: users(:admin),
      store: stores(:warehouse),
      role: roles(:administrator),
      active: true
    )
    users(:admin).update!(default_store: nil)

    post session_path, params: { username: "admin", password: "password123" }
    assert_redirected_to new_store_selection_path
  end

  test "resets session on sign in to prevent fixation" do
    get new_session_path
    fixed = cookies["_shelf_stack_session"]
    post session_path, params: { username: "admin", password: "password123" }
    assert_not_equal fixed, cookies["_shelf_stack_session"]
  end
end
