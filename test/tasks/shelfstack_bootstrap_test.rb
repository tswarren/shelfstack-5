# frozen_string_literal: true

require "test_helper"
require "rake"

class ShelfstackBootstrapTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks
    Rake::Task["shelfstack:bootstrap"].reenable

    @env_keys = %w[
      SHELFSTACK_BOOTSTRAP_ORG_CODE
      SHELFSTACK_BOOTSTRAP_ORG_NAME
      SHELFSTACK_BOOTSTRAP_STORE_CODE
      SHELFSTACK_BOOTSTRAP_STORE_NAME
      SHELFSTACK_BOOTSTRAP_STORE_NUMBER
      SHELFSTACK_BOOTSTRAP_USERNAME
      SHELFSTACK_BOOTSTRAP_PASSWORD
    ]
    @previous_env = @env_keys.index_with { |key| ENV[key] }

    # Fixtures already provide organization "acme" (INV-ORG-001 singleton).
    ENV["SHELFSTACK_BOOTSTRAP_ORG_CODE"] = "acme"
    ENV["SHELFSTACK_BOOTSTRAP_ORG_NAME"] = "Acme Books"
    ENV["SHELFSTACK_BOOTSTRAP_STORE_CODE"] = "B01"
    ENV["SHELFSTACK_BOOTSTRAP_STORE_NAME"] = "Boot Store"
    ENV["SHELFSTACK_BOOTSTRAP_STORE_NUMBER"] = "901"
    ENV["SHELFSTACK_BOOTSTRAP_USERNAME"] = "bootadmin"
    ENV["SHELFSTACK_BOOTSTRAP_PASSWORD"] = "password123"
  end

  teardown do
    @previous_env.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  test "bootstrap does not reactivate disabled user or clear lockout on re-run" do
    Rake::Task["shelfstack:bootstrap"].invoke
    Rake::Task["shelfstack:bootstrap"].reenable

    user = User.find_by!(username: "bootadmin")
    store = Store.find_by!(code: "B01")
    membership = StoreMembership.find_by!(user: user, store: store)

    user.update!(active: false, failed_login_attempts: 5)
    membership.update!(active: false)

    Rake::Task["shelfstack:bootstrap"].invoke

    user.reload
    membership.reload
    assert_not user.active?
    assert_equal 5, user.failed_login_attempts
    assert_not membership.active?
  end

  test "bootstrap does not restore removed administrator permissions" do
    Rake::Task["shelfstack:bootstrap"].invoke
    Rake::Task["shelfstack:bootstrap"].reenable

    role = roles(:administrator)
    permission = permissions(:audit_view)
    RolePermission.find_or_create_by!(role: role, permission: permission)
    RolePermission.find_by!(role: role, permission: permission).destroy!

    assert_not RolePermission.exists?(role: role, permission: permission)

    Rake::Task["shelfstack:bootstrap"].invoke

    assert_not RolePermission.exists?(role: role, permission: permission)
  end

  test "bootstrap aborts when a different organization code is supplied" do
    ENV["SHELFSTACK_BOOTSTRAP_ORG_CODE"] = "otherorg"

    error = assert_raises(RuntimeError) do
      Rake::Task["shelfstack:bootstrap"].invoke
    end
    assert_match(/INV-ORG-001/, error.message)
  end

  test "db:seed only upserts permissions and does not create users" do
    before_user_count = User.count
    load Rails.root.join("db/seeds.rb")
    assert_equal before_user_count, User.count
    assert Permission.exists?(code: "administration.store.view")
  end
end
