# frozen_string_literal: true

class PosLineItem < ApplicationRecord
  LINE_KINDS = %w[product open_ring stored_value].freeze
  STORED_VALUE_OPERATIONS = %w[issue reload].freeze
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
  belongs_to :department, optional: true
  belongs_to :stored_value_account, optional: true
  belongs_to :tax_category, optional: true
  belongs_to :original_tax_category, class_name: "TaxCategory", optional: true
  belongs_to :original_pos_line_item, class_name: "PosLineItem", optional: true
  belongs_to :reverses_pos_line_item, class_name: "PosLineItem", optional: true
  belongs_to :return_reason, optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :removed_by_user, class_name: "User", optional: true
  belongs_to :tax_category_overridden_by_user, class_name: "User", optional: true
  belongs_to :price_overridden_by_user, class_name: "User", optional: true
  has_many :pos_discount_allocations, dependent: :restrict_with_exception
  has_many :pos_line_item_taxes, dependent: :restrict_with_exception
  has_many :linked_return_lines, class_name: "PosLineItem", foreign_key: :original_pos_line_item_id,
           dependent: :restrict_with_exception, inverse_of: :original_pos_line_item
  has_one :post_void_reversing_line, class_name: "PosLineItem", foreign_key: :reverses_pos_line_item_id,
         inverse_of: :reverses_pos_line_item, dependent: :restrict_with_exception
  has_many :product_request_fulfillments, dependent: :restrict_with_exception
  has_many :stored_value_entries, dependent: :restrict_with_exception

  validates :line_kind, presence: true, inclusion: { in: LINE_KINDS }
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :product_line_requires_variant
  validate :open_ring_forbids_variant
  validate :open_ring_requires_description_snapshot
  validate :stored_value_line_shape
  validate :department_is_postable
  validate :individual_line_requires_unit
  validates :stored_value_operation, inclusion: { in: STORED_VALUE_OPERATIONS }, allow_nil: true
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
  # transaction is still open or suspended. A completed post-void reversing line
  # (or completed post-void of the owning transaction) consumes the entire quantity.
  def remaining_returnable_quantity
    return 0 unless sale?
    return 0 if post_voided?
    # Stored-value issue/reload lines are corrected via stored-value or post-void,
    # not ordinary linked returns.
    return 0 if line_kind == "stored_value"

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

  def post_voided?
    return true if post_void_reversing_line&.completed?
    return true if pos_transaction&.post_void_transaction&.completed?

    false
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

  def stored_value_line_shape
    return unless line_kind == "stored_value"

    errors.add(:product_variant, "must be blank for stored-value lines") if product_variant.present?
    errors.add(:inventory_unit, "must be blank for stored-value lines") if inventory_unit.present?
    errors.add(:department, "must be blank for stored-value lines") if department.present?
    errors.add(:tax_category, "must be blank for stored-value lines") if tax_category.present?
    errors.add(:stored_value_account, "is required for stored-value lines") if stored_value_account.blank?
    errors.add(:stored_value_operation, "is required for stored-value lines") if stored_value_operation.blank?
    errors.add(:direction, "must be sale for stored-value lines") unless direction == "sale"
    errors.add(:quantity, "must be 1 for stored-value lines") unless quantity == 1
  end

  def department_is_postable
    return if line_kind == "stored_value"
    return if department.blank?
    return if department.postable?

    errors.add(:department, "must be postable")
  end

  # Mirrors the `pos_line_items_return_requires_link` DB check constraint
  # (application validation complements, not replaces, database protection).
  # Post-void reversing lines use `reverses_pos_line_item_id` instead of the
  # customer-return linkage trio.
  def return_direction_requires_linkage
    return unless direction == "return"
    return if reverses_pos_line_item_id.present?

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
    return if product_request.compatible_with_variant?(product_variant)

    errors.add(:product_request, product_request.compatibility_error_for(product_variant))
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
