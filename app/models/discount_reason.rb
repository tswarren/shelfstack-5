# frozen_string_literal: true

class DiscountReason < ApplicationRecord
  CALCULATION_METHODS = %w[percentage fixed_amount fixed_price].freeze

  belongs_to :organization
  belongs_to :resulting_return_policy, class_name: "ReturnPolicy", optional: true

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :default_calculation_method, presence: true, inclusion: { in: CALCULATION_METHODS }
  validates :requires_approval, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validates :default_rate_bps, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :default_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :maximum_rate_bps, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :resulting_return_policy_belongs_to_same_organization

  private

  def resulting_return_policy_belongs_to_same_organization
    return if resulting_return_policy.blank?

    if resulting_return_policy.organization_id != organization_id
      errors.add(:resulting_return_policy, "must belong to the same organization")
    end
  end
end
