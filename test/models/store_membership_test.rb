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

  test "rejects role from a different organization" do
    other_org = Organization.create!(
      code: "other",
      name: "Other",
      default_currency_code: "USD",
      default_timezone: "UTC"
    )
    foreign_role = Role.create!(
      organization: other_org,
      code: "foreign",
      name: "Foreign"
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
end
