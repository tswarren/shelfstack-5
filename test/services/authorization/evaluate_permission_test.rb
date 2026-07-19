# frozen_string_literal: true

require "test_helper"

module Authorization
  class EvaluatePermissionTest < ActiveSupport::TestCase
    test "allows when membership role has permission" do
      result = EvaluatePermission.call(
        user: users(:admin),
        store: stores(:main_street),
        permission_key: "administration.store.manage"
      )
      assert_equal :allow, result
      assert users(:admin).can?("administration.store.manage", store: stores(:main_street))
    end

    test "denies when permission missing from role" do
      result = EvaluatePermission.call(
        user: users(:clerk),
        store: stores(:main_street),
        permission_key: "administration.store.manage"
      )
      assert_equal :deny, result
    end

    test "denies inactive user store or expired membership" do
      user = users(:admin)
      user.update!(active: false)
      assert_equal :deny, EvaluatePermission.call(
        user: user,
        store: stores(:main_street),
        permission_key: "administration.store.manage"
      )

      user.update!(active: true, locked_at: Time.current)
      assert_equal :deny, EvaluatePermission.call(
        user: user,
        store: stores(:main_street),
        permission_key: "administration.store.manage"
      )

      user.update!(locked_at: nil)
      membership = store_memberships(:admin_main_street)
      # Expire relative to the store's own local calendar date, not the test
      # process's UTC `Date.current` — near UTC midnight those two dates can
      # briefly coincide for a store in a behind-UTC timezone (e.g. America/
      # New_York), making a `Date.current - 1` boundary flaky.
      membership.update!(ends_on: membership.store_local_today - 1)
      assert_equal :deny, EvaluatePermission.call(
        user: user,
        store: stores(:main_street),
        permission_key: "administration.store.manage"
      )
    end

    test "renaming role does not change permission evaluation" do
      role = roles(:administrator)
      role.update!(name: "Completely Different Name", code: "renamed_admin")
      assert_equal :allow, EvaluatePermission.call(
        user: users(:admin),
        store: stores(:main_street),
        permission_key: "administration.store.manage"
      )
    end
  end
end
