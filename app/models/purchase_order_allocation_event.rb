# frozen_string_literal: true

# Append-only quantity-resolution ledger for a Purchase-Order Allocation
# (OD-007). `converted_to_reservation` (Phase 5f) records that allocated
# quantity became a physical Inventory Reservation; `released` records that
# allocated quantity no longer represents usable expected supply for the
# Customer Request. Rows are never edited or deleted — corrections use new
# reversing events.
class PurchaseOrderAllocationEvent < ApplicationRecord
  EVENT_TYPES = %w[converted_to_reservation released].freeze
  RELEASE_REASONS = %w[
    purchase_order_cancelled line_quantity_cancelled vendor_unavailable received_unavailable
    request_cancelled request_quantity_reduced fulfilled_from_earlier_supply
    reallocated_to_other_supply manual_release
  ].freeze

  belongs_to :purchase_order_allocation
  belongs_to :receipt_line, optional: true
  belongs_to :inventory_reservation, optional: true
  belongs_to :user

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :occurred_at, presence: true
  validates :reason, inclusion: { in: RELEASE_REASONS }, allow_nil: true
  validates :posting_key, uniqueness: true, allow_nil: true
  validate :released_requires_reason
  validate :converted_requires_receipt_and_reservation
  validate :quantity_within_remaining_allocation, on: :create

  before_destroy :prevent_mutation
  before_update :prevent_mutation

  def readonly?
    !new_record?
  end

  private

  def released_requires_reason
    return unless event_type == "released"

    errors.add(:reason, "is required for released events") if reason.blank?
  end

  # OD-007: a converted_to_reservation event should identify the Receipt Line
  # and the resulting Inventory Reservation.
  def converted_requires_receipt_and_reservation
    return unless event_type == "converted_to_reservation"

    errors.add(:receipt_line, "is required for converted_to_reservation events") if receipt_line_id.blank?
    errors.add(:inventory_reservation, "is required for converted_to_reservation events") if inventory_reservation_id.blank?
  end

  # Defense-in-depth alongside the caller's row lock on the allocation
  # (Purchasing::ReleaseAllocation) — never rely on this alone under concurrency.
  def quantity_within_remaining_allocation
    return if purchase_order_allocation.blank? || quantity.blank?

    prior_events_sum = purchase_order_allocation.purchase_order_allocation_events.sum(:quantity)
    remaining_before = purchase_order_allocation.quantity - prior_events_sum
    errors.add(:quantity, "exceeds remaining allocation quantity") if quantity > remaining_before
  end

  def prevent_mutation
    errors.add(:base, "purchase order allocation events are append-only")
    throw(:abort)
  end
end
