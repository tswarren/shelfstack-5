# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes username to strip and lowercase" do
    user = User.new(
      username: "  Tom ",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
    assert_equal "tom", user.username
  end

  test "rejects case-variant duplicate usernames" do
    user = User.new(
      username: "ADMIN",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "requires password digest for authentication" do
    user = User.new(username: "nopass")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "default store is optional and does not imply access" do
    user = users(:clerk)
    assert_nil user.default_store
    user.default_store = stores(:main_street)
    assert user.valid?
  end

  test "locked? reflects locked_at" do
    user = users(:admin)
    assert_not user.locked?
    user.locked_at = Time.current
    assert user.locked?
  end

  test "failed_login_attempts cannot be negative" do
    user = users(:admin)
    user.failed_login_attempts = -1
    assert_not user.valid?
  end
end
