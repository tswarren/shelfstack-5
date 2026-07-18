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
end
