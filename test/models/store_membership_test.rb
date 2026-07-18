# frozen_string_literal: true

require "test_helper"

class StoreMembershipTest < ActiveSupport::TestCase
  test "effective_on? respects active and date window" do
    membership = store_memberships(:admin_main_street)
    assert membership.effective_on?(Date.current)

    membership.ends_on = Date.current - 1
    assert_not membership.effective_on?(Date.current)

    membership.ends_on = nil
    membership.active = false
    assert_not membership.effective_on?(Date.current)
  end

  test "effective_on? defaults to store-local today" do
    membership = store_memberships(:admin_main_street)
    membership.store.update!(timezone: "Pacific/Kiritimati")
    membership.starts_on = membership.store_local_today
    membership.ends_on = nil
    membership.active = true

    assert membership.effective_on?
    membership.starts_on = membership.store_local_today + 1
    assert_not membership.effective_on?
  end


  test "rejects role from a different organization" do
    foreign_role = Role.new(
      organization_id: organizations(:acme).id + 999_999,
      code: "foreign",
      name: "Foreign",
      active: true
    )
    membership = store_memberships(:clerk_main_street)
    membership.role = foreign_role
    assert_not membership.valid?
    assert_includes membership.errors[:role], "must belong to the same organization as the store"
  end


  test "rejects inverted date range and invalid rates" do
    membership = store_memberships(:clerk_main_street)
    membership.starts_on = Date.current
    membership.ends_on = Date.current - 1
    assert_not membership.valid?

    membership = store_memberships(:clerk_main_street)
    membership.starts_on = nil
    membership.ends_on = nil
    membership.maximum_discount_rate = 1.5
    assert_not membership.valid?
  end

  test "user_id and store_id are immutable after creation" do
    membership = store_memberships(:clerk_main_street)
    original_user_id = membership.user_id

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      membership.update!(user_id: users(:admin).id)
    end
    assert_equal original_user_id, membership.reload.user_id
  end
end
