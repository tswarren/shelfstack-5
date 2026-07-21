# frozen_string_literal: true

# Expected supply committed from one `ordered` Purchase-Order Line to one
# Customer Request (ADR-0015 §6; OD-007). Never persists a received/fulfilled
# status — resolution is recorded through append-only
# `purchase_order_allocation_events`, and remaining quantity is always
# derived: `quantity - converted_quantity - released_quantity`. The
# allocation itself is otherwise immutable once created (see
# Purchasing::CreateAllocation / Purchasing::ReleaseAllocation).
class PurchaseOrderAllocation < ApplicationRecord
  attr_readonly :purchase_order_line_id, :product_request_id, :quantity, :created_by_user_id

  belongs_to :purchase_order_line
  belongs_to :product_request
  belongs_to :created_by_user, class_name: "User"
  has_many :purchase_order_allocation_events, dependent: :restrict_with_exception

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :product_request_id, uniqueness: { scope: :purchase_order_line_id }
  validate :product_request_is_customer_request
  validate :store_matches
  validate :variant_compatible_with_product_request

  # Appends a `released` event. Callers must hold a row lock on this
  # allocation (e.g. `PurchaseOrderAllocation.lock.find(...)`) before calling,
  # so concurrent resolution against the same allocation is serialized.
  def release!(quantity:, reason:, actor:, note: nil, occurred_at: nil, posting_key: nil)
    quantity = quantity.to_i
    raise ArgumentError, "quantity must be a positive integer" unless quantity.positive?
    unless PurchaseOrderAllocationEvent::RELEASE_REASONS.include?(reason.to_s)
      raise ArgumentError, "reason must be one of #{PurchaseOrderAllocationEvent::RELEASE_REASONS.join(', ')}"
    end
    if quantity > remaining_quantity
      raise ArgumentError, "release quantity exceeds remaining allocation quantity (#{remaining_quantity} remaining)"
    end

    purchase_order_allocation_events.create!(
      event_type: "released",
      quantity: quantity,
      reason: reason.to_s,
      note: note,
      occurred_at: occurred_at || Time.current,
      user: actor,
      posting_key: posting_key
    )
  end

  def converted_quantity
    purchase_order_allocation_events.where(event_type: "converted_to_reservation").sum(:quantity)
  end

  def released_quantity
    purchase_order_allocation_events.where(event_type: "released").sum(:quantity)
  end

  # OD-007: "remaining allocation quantity = allocated − converted − released";
  # must never be negative.
  def remaining_quantity
    [ quantity - converted_quantity - released_quantity, 0 ].max
  end

  # Derived presentation label only (OD-007 "Allocation states presented by
  # the interface") — never persisted.
  def state
    remaining = remaining_quantity
    return "active" if remaining == quantity

    converted = converted_quantity
    released = released_quantity
    return "partially_resolved" if remaining.positive?
    return "converted" if released.zero?
    return "released" if converted.zero?

    "resolved_mixed"
  end

  private

  def product_request_is_customer_request
    return if product_request.blank?
    return if product_request.customer_request?

    errors.add(:product_request, "must be a customer request")
  end

  def store_matches
    return if purchase_order_line.blank? || product_request.blank?

    po_store_id = purchase_order_line.purchase_order&.store_id
    return if po_store_id.blank?
    return if po_store_id == product_request.store_id

    errors.add(:base, "purchase order line and product request must belong to the same store")
  end

  def variant_compatible_with_product_request
    return if product_request.blank? || purchase_order_line.blank?

    variant = purchase_order_line.product_variant
    return if product_request.compatible_with_variant?(variant)

    errors.add(:product_request, product_request.compatibility_error_for(variant) || "is incompatible with the purchase order line")
  end
end
