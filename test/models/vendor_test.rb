# frozen_string_literal: true

require "test_helper"

class VendorTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "requires code and name unique within organization" do
    vendor = @organization.vendors.new(code: "INGRAM", name: "Duplicate")
    assert_not vendor.valid?
    assert_includes vendor.errors[:code], "has already been taken"
  end

  test "active inclusion" do
    vendor = @organization.vendors.new(code: "NEW", name: "New Vendor", active: nil)
    assert_not vendor.valid?
    assert_includes vendor.errors[:active], "is not included in the list"
  end

  test "deactivate rather than delete leaves record" do
    vendor = vendors(:acme_distributor)
    vendor.update!(active: false)
    assert_not vendor.active?
    assert Vendor.exists?(vendor.id)
  end
end
