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
      SHELFSTACK_BOOTSTRAP_USERNAME
      SHELFSTACK_BOOTSTRAP_PASSWORD
    ]
    @previous_env = @env_keys.index_with { |key| ENV[key] }

    ENV["SHELFSTACK_BOOTSTRAP_ORG_CODE"] = "bootorg"
    ENV["SHELFSTACK_BOOTSTRAP_ORG_NAME"] = "Boot Org"
    ENV["SHELFSTACK_BOOTSTRAP_STORE_CODE"] = "B01"
    ENV["SHELFSTACK_BOOTSTRAP_STORE_NAME"] = "Boot Store"
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

  test "db:seed only upserts permissions and does not create users" do
    before_user_count = User.count
    load Rails.root.join("db/seeds.rb")
    assert_equal before_user_count, User.count
    assert Permission.exists?(code: "administration.store.view")
  end
end
