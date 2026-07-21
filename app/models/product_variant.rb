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

  # Registered before the `dependent: :restrict_with_exception` associations
  # below so the friendlier "last variant" validation error always wins over
  # a raised DeleteRestrictionError when both conditions hold.
  before_destroy :prevent_destroying_last_variant_of_sellable_product

  has_many :stock_balances, dependent: :restrict_with_exception
  has_many :inventory_ledger_entries, dependent: :restrict_with_exception
  has_many :inventory_reservations, dependent: :restrict_with_exception
  has_many :inventory_adjustment_lines, dependent: :restrict_with_exception
  has_many :inventory_units, dependent: :restrict_with_exception
  has_many :pos_line_items, dependent: :restrict_with_exception
  has_many :product_variant_vendors, dependent: :restrict_with_exception
  has_many :vendors, through: :product_variant_vendors
  has_many :purchase_order_lines, dependent: :restrict_with_exception
  has_many :receipt_lines, dependent: :restrict_with_exception

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
  validate :sku_is_generated_28
  validate :single_structure_allows_only_one_variant, on: :create

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

  def sku_is_generated_28
    return if sku.blank?

    normalized = Identifiers::Normalize.call(sku)
    return if normalized.type == :generated_28 && normalized.validation_status == :valid

    errors.add(:sku, "must be a valid generated namespace 28 EAN-13")
  end

  def single_structure_allows_only_one_variant
    return if product.blank?
    return unless product.variant_structure == "single"
    return unless product.product_variants.where.not(id: id).exists?

    errors.add(:base, "single products may have only one variant")
  end

  def prevent_destroying_last_variant_of_sellable_product
    return if product.blank?
    return unless product.sellable?
    return if product.product_variants.where.not(id: id).exists?

    errors.add(:base, "cannot remove the last variant from a sellable product")
    throw(:abort)
  end
end
