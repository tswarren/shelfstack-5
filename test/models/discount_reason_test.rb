# frozen_string_literal: true

require "test_helper"

class DiscountReasonTest < ActiveSupport::TestCase
  test "code is unique within an organization" do
    DiscountReason.create!(
      organization: organizations(:acme),
      code: "damage",
      name: "Damage",
      default_calculation_method: "percentage",
      requires_approval: false,
      active: true
    )

    duplicate = DiscountReason.new(
      organization: organizations(:acme),
      code: "damage",
      name: "Damage again",
      default_calculation_method: "percentage",
      requires_approval: false,
      active: true
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "resulting return policy must belong to the same organization" do
    # INV-ORG-001 forbids a second Organization row; validate against an
    # unsaved policy stamped with a different organization_id.
    foreign_policy = ReturnPolicy.new(
      organization_id: organizations(:acme).id + 1,
      code: "foreign", name: "Foreign",
      active: true, final_sale: false
    )

    reason = DiscountReason.new(
      organization: organizations(:acme),
      code: "promo",
      name: "Promo",
      default_calculation_method: "percentage",
      requires_approval: false,
      active: true,
      resulting_return_policy: foreign_policy
    )
    refute reason.valid?
    assert_includes reason.errors[:resulting_return_policy], "must belong to the same organization"
  end
end
