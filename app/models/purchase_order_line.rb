# frozen_string_literal: true

class PurchaseOrderLine < ApplicationRecord
  COST_ENTRY_METHODS = %w[discount_from_list direct_net_cost].freeze

  # Line identity is immutable once the parent Purchase Order is placed; only
  # cancelled_quantity may change (architectural-locks.md#purchase-order-and-receipt-linkage,
  # vendors-and-purchasing.md#mutability-after-placement).
  IDENTITY_ATTRIBUTES = %w[
    product_variant_id product_variant_vendor_id ordered_quantity cost_entry_method
    list_cost_cents discount_bps expected_unit_cost_cents expected_extended_cost_cents
    description_snapshot identifier_snapshot sku_snapshot vendor_item_code_snapshot
    returnable_snapshot cost_provenance position
  ].freeze

  belongs_to :purchase_order
  belongs_to :product_variant
  belongs_to :product_variant_vendor, optional: true

  validates :position, numericality: { only_integer: true }
  validates :ordered_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :cancelled_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :received_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cost_entry_method, presence: true, inclusion: { in: COST_ENTRY_METHODS }
  validates :expected_unit_cost_cents, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :list_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :expected_extended_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validate :cancelled_quantity_within_ordered
  validate :variant_matches_store_organization
  validate :source_matches_variant_and_vendor
  validate :discount_from_list_requires_list_cost

  before_validation :apply_deterministic_cost_calculations
  before_create :require_addable_parent_status
  before_update :require_permitted_change_for_parent_status
  # Registered after require_draft_parent so the friendlier "draft only"
  # message always wins over a raised DeleteRestrictionError when both
  # conditions hold (mirrors ProductVariant's destroy-callback ordering).
  before_destroy :require_draft_parent
  has_many :receipt_lines, dependent: :restrict_with_exception
  has_many :purchase_order_allocations, dependent: :restrict_with_exception

  # max(ordered − received − cancelled, 0) (vendors-and-purchasing.md#purchase-order-line).
  def open_quantity
    [ ordered_quantity.to_i - received_quantity.to_i - cancelled_quantity.to_i, 0 ].max
  end

  private

  def cancelled_quantity_within_ordered
    return if cancelled_quantity.nil? || ordered_quantity.nil?
    return if cancelled_quantity <= ordered_quantity

    errors.add(:cancelled_quantity, "must not exceed ordered quantity")
  end

  def variant_matches_store_organization
    return if purchase_order.blank? || purchase_order.store.blank? || product_variant.blank?
    return if product_variant.organization.id == purchase_order.store.organization_id

    errors.add(:product_variant, "must belong to the same organization as the purchase order's store")
  end

  def source_matches_variant_and_vendor
    return if product_variant_vendor.blank? || purchase_order.blank?

    if product_variant_vendor.vendor_id != purchase_order.vendor_id
      errors.add(:product_variant_vendor, "must belong to the purchase order's vendor")
    end
    if product_variant.present? && product_variant_vendor.product_variant_id != product_variant.id
      errors.add(:product_variant_vendor, "must match the line's product variant")
    end
  end

  def discount_from_list_requires_list_cost
    return unless cost_entry_method == "discount_from_list"
    return if list_cost_cents.present?

    errors.add(:list_cost_cents, "is required when using discount-from-list pricing")
  end

  # discount_from_list derives expected_unit_cost_cents deterministically from
  # list_cost_cents/discount_bps; direct_net_cost leaves it as manual entry
  # (vendors-and-purchasing.md#expected-cost). expected_extended_cost_cents is
  # always a derived rollup.
  def apply_deterministic_cost_calculations
    if cost_entry_method == "discount_from_list" && list_cost_cents.present?
      self.expected_unit_cost_cents = Inventory::Rounding.round_half_up(
        list_cost_cents.to_i * (10_000 - discount_bps.to_i), 10_000
      )
    end

    if expected_unit_cost_cents.present? && ordered_quantity.present?
      self.expected_extended_cost_cents =
        Inventory::Rounding.multiply_round_half_up(expected_unit_cost_cents, ordered_quantity)
    end
  end

  def require_addable_parent_status
    return if purchase_order.blank?
    return if purchase_order.draft? || purchase_order.ordered?

    errors.add(:base, "lines cannot be added once the purchase order is closed or cancelled")
    throw(:abort)
  end

  def require_permitted_change_for_parent_status
    return if purchase_order.blank? || purchase_order.draft?

    if purchase_order.ordered?
      changed_identity = changed_attribute_names_to_save & IDENTITY_ATTRIBUTES
      return if changed_identity.empty?

      errors.add(:base, "line identity is immutable after placement; only cancelled_quantity may change")
      throw(:abort)
    end

    errors.add(:base, "lines cannot be changed once the purchase order is closed or cancelled")
    throw(:abort)
  end

  def require_draft_parent
    return if purchase_order&.draft?

    errors.add(:base, "lines can only be removed while the purchase order is draft")
    throw(:abort)
  end
end
