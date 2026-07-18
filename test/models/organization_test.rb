# frozen_string_literal: true

require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "requires code name currency and timezone" do
    organization = Organization.new
    assert_not organization.valid?
    assert_includes organization.errors[:code], "can't be blank"
    assert_includes organization.errors[:name], "can't be blank"
    assert_includes organization.errors[:default_currency_code], "can't be blank"
    assert_includes organization.errors[:default_timezone], "can't be blank"
  end

  test "enforces unique code" do
    duplicate = organizations(:acme).dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "rejects a second organization under INV-ORG-001" do
    second = Organization.new(
      code: "beta",
      name: "Beta",
      default_currency_code: "USD",
      default_timezone: "America/New_York"
    )
    assert_not second.valid?
    assert_includes second.errors[:base], "installation already has an organization (INV-ORG-001)"
  end

  test "rejects unrecognized default timezone" do
    organization = organizations(:acme)
    organization.default_timezone = "Not/A_Zone"
    assert_not organization.valid?
    assert_includes organization.errors[:default_timezone], "is not a recognized time zone"
  end
end
