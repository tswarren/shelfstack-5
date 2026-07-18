# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  STATUSES = %w[active inactive discontinued].freeze
  INVENTORY_TRACKING_MODES = %w[quantity individual none].freeze
  DISCOUNTABILITY_SETTINGS = %w[default discountable non_discountable].freeze
  RETURNABILITY_SETTINGS = %w[default returnable non_returnable].freeze

  belongs_to :product
  belongs_to :default_product_condition, class_name: "ProductCondition", optional: true
  belongs_to :department, optional: true
  belongs_to :tax_category, class_name: "TaxCategory", optional: true
  belongs_to :merchandise_class, optional: true
  belongs_to :return_policy, optional: true

  attr_readonly :sku

  validates :sku, presence: true, uniqueness: true
  validates :name, presence: true
  validates :inventory_tracking_mode, presence: true, inclusion: { in: INVENTORY_TRACKING_MODES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :sellable, inclusion: { in: [ true, false ] }
  validates :purchasable, inclusion: { in: [ true, false ] }
  validates :regular_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :discountability_setting, inclusion: { in: DISCOUNTABILITY_SETTINGS }, allow_nil: true
  validates :returnability_setting, inclusion: { in: RETURNABILITY_SETTINGS }, allow_nil: true
  validate :sellable_requires_price
  validate :availability_window_order
  validate :classification_belongs_to_organization
  validate :department_postable_when_present

  delegate :organization, to: :product

  private

  def sellable_requires_price
    return unless sellable?
    return if regular_price_cents.present?

    errors.add(:regular_price_cents, "must be present when variant is sellable")
  end

  def availability_window_order
    return if available_from.blank? || available_until.blank?
    return if available_from <= available_until

    errors.add(:available_until, "must be on or after available_from")
  end

  def classification_belongs_to_organization
    org_id = product&.organization_id
    return if org_id.blank?

    if department.present? && department.organization_id != org_id
      errors.add(:department, "must belong to the same organization")
    end
    if tax_category.present? && tax_category.organization_id != org_id
      errors.add(:tax_category, "must belong to the same organization")
    end
    if merchandise_class.present? && merchandise_class.organization_id != org_id
      errors.add(:merchandise_class, "must belong to the same organization")
    end
    if return_policy.present? && return_policy.organization_id != org_id
      errors.add(:return_policy, "must belong to the same organization")
    end
  end

  def department_postable_when_present
    return if department.blank? || department.postable?

    errors.add(:department, "must be postable")
  end
end
