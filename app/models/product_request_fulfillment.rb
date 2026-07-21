# frozen_string_literal: true

# Final customer fulfilment fact for a Customer Request (OD-007). Distinct
# from Purchase-Order Allocation (expected supply) and Inventory Reservation
# (physical supply): a fulfilment records merchandise actually sold/delivered
# against the request. Append-only — quantity is always positive; a `reverse`
# row (created when a linked POS return undoes a completed fulfilled sale
# line) references the original `fulfill` row via `linked_fulfilment_id`
# rather than editing or deleting it (ADR-0008 "completed activity is
# immutable").
class ProductRequestFulfillment < ApplicationRecord
  KINDS = %w[fulfill reverse].freeze

  belongs_to :product_request
  belongs_to :inventory_reservation, optional: true
  belongs_to :pos_line_item
  belongs_to :fulfilled_by_user, class_name: "User"
  belongs_to :linked_fulfilment, class_name: "ProductRequestFulfillment", optional: true
  has_many :reversals, class_name: "ProductRequestFulfillment", foreign_key: :linked_fulfilment_id,
           inverse_of: :linked_fulfilment, dependent: :restrict_with_exception

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :fulfilled_at, presence: true
  validates :posting_key, presence: true, uniqueness: true
  validate :reverse_requires_linked_fulfilment
  validate :fulfil_forbids_linked_fulfilment
  validate :reversal_quantity_within_linked_fulfilment, on: :create

  before_destroy :prevent_mutation
  before_update :prevent_mutation

  def readonly?
    !new_record?
  end

  def fulfil?
    kind == "fulfill"
  end

  def reverse?
    kind == "reverse"
  end

  private

  def reverse_requires_linked_fulfilment
    return unless kind == "reverse"

    errors.add(:linked_fulfilment, "is required for reverse fulfilments") if linked_fulfilment_id.blank?
  end

  def fulfil_forbids_linked_fulfilment
    return unless kind == "fulfill"

    errors.add(:linked_fulfilment, "must be blank for fulfill records") if linked_fulfilment_id.present?
  end

  # Defense-in-depth alongside the caller's row lock on the linked fulfilment
  # (Requests::ReverseFulfillment) — never rely on this alone under concurrency.
  def reversal_quantity_within_linked_fulfilment
    return if linked_fulfilment.blank? || quantity.blank?

    prior_reversed = linked_fulfilment.reversals.where.not(id: id).sum(:quantity)
    remaining = linked_fulfilment.quantity - prior_reversed
    errors.add(:quantity, "exceeds the linked fulfilment's remaining reversible quantity") if quantity > remaining
  end

  def prevent_mutation
    errors.add(:base, "product request fulfilments are append-only")
    throw(:abort)
  end
end
