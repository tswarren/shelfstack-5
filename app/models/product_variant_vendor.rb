# frozen_string_literal: true

class ProductVariantVendor < ApplicationRecord
  belongs_to :product_variant
  belongs_to :vendor

  validates :vendor_id, uniqueness: { scope: :product_variant_id }
  validates :preferred, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validates :list_cost_cents, :expected_unit_cost_cents, :discount_bps,
            :minimum_order_quantity, :order_multiple,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validate :vendor_and_variant_share_organization

  delegate :organization, to: :vendor

  private

  def vendor_and_variant_share_organization
    return if vendor.blank? || product_variant.blank?
    return if vendor.organization_id == product_variant.organization.id

    errors.add(:product_variant, "must belong to the same organization as the vendor")
  end
end
