# frozen_string_literal: true

require "test_helper"

class ReceiptTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @vendor = vendors(:acme_distributor)
  end

  test "requires receipt_number unique within store" do
    receipt = Receipt.new(store: @store, vendor: @vendor, receipt_number: "001-RCPT-000001", status: "draft")

    assert_not receipt.valid?
    assert_includes receipt.errors[:receipt_number], "has already been taken"
  end

  test "vendor must belong to the same organization as the store" do
    fake_org = Organization.new(
      id: organizations(:acme).id + 999_999, code: "other3", name: "Other Org 3",
      default_currency_code: "USD", default_timezone: "America/New_York"
    )
    other_vendor = Vendor.new(organization: fake_org, code: "OTH2", name: "Other Vendor 2", active: true)
    receipt = Receipt.new(store: @store, vendor: other_vendor, receipt_number: "001-RCPT-999999", status: "draft")

    assert_not receipt.valid?
    assert_includes receipt.errors[:vendor], "must belong to the same organization as the store"
  end

  test "status must be one of the accepted values" do
    receipt = receipts(:draft_receipt)
    receipt.status = "bogus"

    assert_not receipt.valid?
    assert_includes receipt.errors[:status], "is not included in the list"
  end

  test "draft?/posted?/cancelled? reflect status" do
    receipt = receipts(:draft_receipt)
    assert receipt.draft?
    refute receipt.posted?
    refute receipt.cancelled?
  end
end
