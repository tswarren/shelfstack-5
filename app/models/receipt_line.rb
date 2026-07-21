# frozen_string_literal: true

# Suggested attributes per docs/domains/receiving-and-inventory.md#receipt-line.
# Only accepted quantity ever enters inventory; rejected quantity never does.
# Lines are only addable/editable while the parent Receipt is draft — posting
# and cancellation freeze the Receipt (mirrors PurchaseOrderLine's
# draft-only mutability guard).
class ReceiptLine < ApplicationRecord
  COST_QUALITIES = %w[actual estimated unknown confirmed_zero].freeze
  COST_PROVENANCES = Inventory::ResolveReceiptLineCost::CONTROLLED_PROVENANCES

  belongs_to :receipt
  belongs_to :product_variant
  belongs_to :purchase_order_line, optional: true

  validates :position, numericality: { only_integer: true }
  validates :delivered_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :accepted_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rejected_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :accepted_unavailable_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :actual_unit_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cost_quality, inclusion: { in: COST_QUALITIES }, allow_nil: true
  validates :cost_provenance, inclusion: { in: COST_PROVENANCES }, allow_nil: true
  validate :accepted_unavailable_within_accepted
  validate :accepted_and_rejected_within_delivered
  validate :variant_matches_store_organization
  validate :purchase_order_line_matches_receipt_vendor_and_store
  validate :cost_tuple_is_consistent

  # The receipt form's blank select option submits "" which must become nil —
  # inclusion allow_nil does not treat blank strings as nil, and the DB check
  # constraint rejects empty strings.
  before_validation :normalize_blank_cost_fields
  # Selecting a Purchase-Order Line without a variant adopts that line's item;
  # an explicit mismatched variant is still rejected by validation below.
  before_validation :derive_variant_from_purchase_order_line

  before_create :require_draft_parent
  before_update :require_draft_parent
  before_destroy :require_draft_parent

  # Physically received but not sellable (still increases On Hand; the
  # receiving-and-inventory domain: "Unavailable inventory remains On Hand").
  def sellable_accepted_quantity
    accepted_quantity.to_i - accepted_unavailable_quantity.to_i
  end

  private

  def normalize_blank_cost_fields
    self.cost_quality = nil if cost_quality.blank?
    self.cost_provenance = nil if cost_provenance.blank?
  end

  def derive_variant_from_purchase_order_line
    return if purchase_order_line.blank?
    return if product_variant_id.present?

    self.product_variant_id = purchase_order_line.product_variant_id
  end

  def cost_tuple_is_consistent
    blank_tuple = actual_unit_cost_cents.nil? && cost_quality.nil? && cost_provenance.nil?
    return if blank_tuple

    case cost_quality
    when "unknown"
      errors.add(:actual_unit_cost_cents, "must be blank for unknown cost") unless actual_unit_cost_cents.nil?
      errors.add(:cost_provenance, "must be unknown") unless cost_provenance == "unknown"
    when "confirmed_zero"
      errors.add(:actual_unit_cost_cents, "must be zero for confirmed zero cost") unless actual_unit_cost_cents == 0
      errors.add(:cost_provenance, "must be confirmed_zero") unless cost_provenance == "confirmed_zero"
    when "estimated"
      errors.add(:actual_unit_cost_cents, "is required for estimated cost") if actual_unit_cost_cents.nil?
      if cost_provenance.present? &&
         !Inventory::ResolveReceiptLineCost::AUTO_PROVENANCES.include?(cost_provenance) &&
         cost_provenance != "manual_receipt"
        errors.add(:cost_provenance, "is not valid for estimated cost")
      end
      if Inventory::ResolveReceiptLineCost::AUTO_PROVENANCES.include?(cost_provenance.to_s)
        # auto provenance requires estimated — already in this branch
      elsif cost_provenance == "manual_receipt"
        # allowed: operator may mark a manual amount as estimated
      elsif cost_provenance.nil?
        errors.add(:cost_provenance, "is required when cost quality is set")
      end
    when "actual"
      errors.add(:actual_unit_cost_cents, "is required for actual cost") if actual_unit_cost_cents.nil?
      errors.add(:cost_provenance, "must be manual_receipt for actual cost") unless cost_provenance == "manual_receipt"
    when nil
      unless actual_unit_cost_cents.nil? && cost_provenance.nil?
        errors.add(:cost_quality, "is required when cost amount or provenance is set")
      end
    end

    if Inventory::ResolveReceiptLineCost::AUTO_PROVENANCES.include?(cost_provenance.to_s) &&
       cost_quality != "estimated"
      errors.add(:cost_quality, "must be estimated for suggested provenance")
    end
  end

  def accepted_unavailable_within_accepted
    return if accepted_unavailable_quantity.nil? || accepted_quantity.nil?
    return if accepted_unavailable_quantity <= accepted_quantity

    errors.add(:accepted_unavailable_quantity, "must not exceed accepted quantity")
  end

  def accepted_and_rejected_within_delivered
    return if [ accepted_quantity, rejected_quantity, delivered_quantity ].any?(&:nil?)
    return if accepted_quantity + rejected_quantity <= delivered_quantity

    errors.add(:base, "accepted plus rejected quantity must not exceed delivered quantity")
  end

  def variant_matches_store_organization
    return if receipt.blank? || receipt.store.blank? || product_variant.blank?
    return if product_variant.organization.id == receipt.store.organization_id

    errors.add(:product_variant, "must belong to the same organization as the receipt's store")
  end

  def purchase_order_line_matches_receipt_vendor_and_store
    return if purchase_order_line.blank? || receipt.blank?

    order = purchase_order_line.purchase_order
    if order.vendor_id != receipt.vendor_id
      errors.add(:purchase_order_line, "must belong to the receipt's vendor")
    end
    if order.store_id != receipt.store_id
      errors.add(:purchase_order_line, "must belong to the receipt's store")
    end
    if product_variant.present? && purchase_order_line.product_variant_id != product_variant.id
      errors.add(:purchase_order_line, "must match the line's product variant")
    end
  end

  def require_draft_parent
    return if receipt&.draft?

    errors.add(:base, "lines can only be changed while the receipt is draft")
    throw(:abort)
  end
end
