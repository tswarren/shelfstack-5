# frozen_string_literal: true

require "test_helper"

class TenderTypeTest < ActiveSupport::TestCase
  test "code is unique within an organization" do
    duplicate = TenderType.new(
      organization: organizations(:acme),
      code: tender_types(:cash).code,
      name: "Duplicate cash",
      tender_category: "cash",
      payment_enabled: true,
      refund_enabled: true,
      allows_over_tender: true,
      provides_change: true,
      reference_1_requirement: "none",
      reference_2_requirement: "none",
      active: true
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "shortcut is unique within an organization when present" do
    duplicate = TenderType.new(
      organization: organizations(:acme),
      code: "cash_alt",
      name: "Cash alt",
      tender_category: "cash",
      shortcut: tender_types(:cash).shortcut,
      payment_enabled: true,
      refund_enabled: true,
      allows_over_tender: true,
      provides_change: true,
      reference_1_requirement: "none",
      reference_2_requirement: "none",
      active: true
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:shortcut], "has already been taken"
  end
end
