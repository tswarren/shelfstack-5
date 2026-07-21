# frozen_string_literal: true

class PosLineItem < ApplicationRecord
  LINE_KINDS = %w[product open_ring].freeze
  STATUSES = %w[pending completed removed].freeze
  DIRECTIONS = %w[sale return].freeze
  # Mirrors docs/domains/receiving-and-inventory.md "Return dispositions". Only
  # `return_to_stock` restores sellable stock; the others are recorded for audit
  # but do not post inventory effects in Phase 4e (inspection/damaged/RTV bucket
  # representation remains OD-010, and full RTV is a deferred capability).
  RETURN_DISPOSITIONS = %w[
    return_to_stock inspection_required damaged return_to_vendor discard non_inventory
  ].freeze
  # Domain "Customer Returns": linked_sale is the only source implemented in
  # Phase 4e; external_receipt/gift_receipt/no_receipt remain unlinked-return
  # scope (pos.return.no_receipt permission is seeded but has no service yet).
  RETURN_SOURCES = %w[linked_sale external_receipt gift_receipt no_receipt].freeze

  belongs_to :pos_transaction
  belongs_to :product_variant, optional: true
  belongs_to :inventory_unit, optional: true
  belongs_to :product_request, optional: true
  belongs_to :department
  belongs_to :tax_category, optional: true
  belongs_to :original_tax_category, class_name: "TaxCategory", optional: true
  belongs_to :original_pos_line_item, class_name: "PosLineItem", optional: true
  belongs_to :return_reason, optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :removed_by_user, class_name: "User", optional: true
  belongs_to :tax_category_overridden_by_user, class_name: "User", optional: true
  belongs_to :price_overridden_by_user, class_name: "User", optional: true
  has_many :pos_discount_allocations, dependent: :restrict_with_exception
  has_many :pos_line_item_taxes, dependent: :restrict_with_exception
  has_many :linked_return_lines, class_name: "PosLineItem", foreign_key: :original_pos_line_item_id,
           dependent: :restrict_with_exception, inverse_of: :original_pos_line_item
  has_many :product_request_fulfillments, dependent: :restrict_with_exception

  validates :line_kind, presence: true, inclusion: { in: LINE_KINDS }
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :product_line_requires_variant
  validate :open_ring_forbids_variant
  validate :open_ring_requires_description_snapshot
  validate :department_is_postable
  validate :individual_line_requires_unit
  validates :return_disposition, inclusion: { in: RETURN_DISPOSITIONS }, allow_nil: true
  validates :return_source, inclusion: { in: RETURN_SOURCES }, allow_nil: true
  validate :return_direction_requires_linkage
  validate :product_request_requires_product_sale
  validate :product_request_matches_variant

  scope :pending, -> { where(status: "pending") }
  scope :sales, -> { where(direction: "sale") }
  scope :returns, -> { where(direction: "return") }

  def pending?
    status == "pending"
  end

  def removed?
    status == "removed"
  end

  def completed?
    status == "completed"
  end

  def tax_category_overridden?
    tax_category_overridden_at.present?
  end

  def price_overridden?
    price_overridden_at.present?
  end

  def extended_price_cents
    quantity * unit_price_cents
  end

  def discount_amount_cents
    pos_discount_allocations.sum(:allocated_amount_cents)
  end

  def tax_amount_cents
    pos_line_item_taxes.sum(:amount_cents)
  end

  def effective_description
    return description_snapshot if description_snapshot.present?
    return product_variant.product.name if line_kind == "product" && product_variant.present?

    department&.name
  end

  def sale?
    direction == "sale"
  end

  def return?
    direction == "return"
  end

  # Domain invariant "Linked Returns do not exceed remaining quantity": counts
  # completed linked returns and pending linked returns only while their owning
  # transaction is still open or suspended. Cancelled transactions soft-remove
  # pending lines; this join is a safety net if a pending line somehow remains.
  def remaining_returnable_quantity
    return 0 unless sale?

    already_returned = PosLineItem
      .joins(:pos_transaction)
      .where(original_pos_line_item_id: id)
      .where(
        "(pos_line_items.status = 'completed') OR " \
        "(pos_line_items.status = 'pending' AND pos_transactions.status IN ('open', 'suspended'))"
      )
      .sum(:quantity)
    quantity - already_returned
  end

  private

  def product_line_requires_variant
    return unless line_kind == "product"

    errors.add(:product_variant, "is required for product lines") if product_variant.blank?
  end

  def open_ring_forbids_variant
    return unless line_kind == "open_ring"

    errors.add(:product_variant, "must be blank for open-ring lines") if product_variant.present?
  end

  def open_ring_requires_description_snapshot
    return unless line_kind == "open_ring"

    errors.add(:description_snapshot, "must be resolved before save") if description_snapshot.blank?
  end

  def department_is_postable
    return if department.blank?
    return if department.postable?

    errors.add(:department, "must be postable")
  end

  # Mirrors the `pos_line_items_return_requires_link` DB check constraint
  # (application validation complements, not replaces, database protection).
  def return_direction_requires_linkage
    return unless direction == "return"

    errors.add(:original_pos_line_item, "is required for return lines") if original_pos_line_item_id.blank?
    errors.add(:return_reason, "is required for return lines") if return_reason_id.blank?
    errors.add(:return_disposition, "is required for return lines") if return_disposition.blank?
  end

  # Mirrors the `pos_line_items_product_request_requires_product_sale` DB
  # check constraint.
  def product_request_requires_product_sale
    return if product_request_id.blank?

    errors.add(:product_request, "may only be set on product sale lines") unless line_kind == "product" && direction == "sale"
  end

  def product_request_matches_variant
    return if product_request.blank? || product_variant.blank?
    return if product_request.product_variant_id.blank? || product_request.product_variant_id == product_variant_id

    errors.add(:product_request, "must match the line's product variant")
  end

  def individual_line_requires_unit
    return unless line_kind == "product"
    return if product_variant.blank?

    if product_variant.inventory_tracking_mode == "individual"
      if inventory_unit.blank?
        errors.add(:inventory_unit, "is required for individually tracked lines")
      elsif inventory_unit.product_variant_id != product_variant_id
        errors.add(:inventory_unit, "must match the line's product variant")
      end
    elsif inventory_unit.present?
      errors.add(:inventory_unit, "must be blank unless the variant is individually tracked")
    end
  end
end
