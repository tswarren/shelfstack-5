# frozen_string_literal: true

# Demand record unifying Customer Requests, staff suggestions, stock
# replenishment, and frontlist selections (docs/domains/product-requests.md).
# Customer Requests remain open as continuing fulfilment obligations;
# non-customer types are buyer-decision records resolved through
# Requests::ResolveProductRequest and never create Purchase-Order
# Allocations (ADR-0015; deferred to Phase 5e/5f).
class ProductRequest < ApplicationRecord
  REQUEST_TYPES = %w[customer_request staff_suggestion stock_replenishment frontlist_selection].freeze
  NON_CUSTOMER_REQUEST_TYPES = (REQUEST_TYPES - %w[customer_request]).freeze
  STATUSES = %w[open fulfilled declined cancelled closed].freeze
  PRIORITIES = %w[normal high urgent].freeze
  RESOLUTIONS = %w[ordered declined deferred duplicate superseded no_longer_needed].freeze

  belongs_to :store
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :requested_by_user, class_name: "User"
  belongs_to :assigned_buyer_user, class_name: "User", optional: true
  belongs_to :resolved_by_user, class_name: "User", optional: true
  belongs_to :supersedes_product_request, class_name: "ProductRequest", optional: true
  has_many :superseding_product_requests, class_name: "ProductRequest",
           foreign_key: :supersedes_product_request_id, inverse_of: :supersedes_product_request,
           dependent: :restrict_with_exception
  has_many :purchase_order_allocations, dependent: :restrict_with_exception
  has_many :product_request_fulfillments, dependent: :restrict_with_exception

  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :requested_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true
  validates :resolved_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :resolved_quantity_within_requested
  validate :product_belongs_to_store_organization
  validate :variant_matches_product
  validate :supersedes_within_same_store
  validate :supersedes_not_self

  scope :open_requests, -> { where(status: "open") }

  delegate :organization, to: :store

  def open?
    status == "open"
  end

  def cancelled?
    status == "cancelled"
  end

  def closed?
    status == "closed"
  end

  def declined?
    status == "declined"
  end

  def customer_request?
    request_type == "customer_request"
  end

  def non_customer_request?
    !customer_request?
  end

  def fulfilled?
    status == "fulfilled"
  end

  # Sum of valid Product Request Fulfilments (OD-007 "fulfilled quantity =
  # sum of valid Product Request Fulfilments"): append-only `fulfill` rows
  # minus their `reverse` rows.
  def fulfilled_quantity
    product_request_fulfillments.where(kind: "fulfill").sum(:quantity) -
      product_request_fulfillments.where(kind: "reverse").sum(:quantity)
  end

  # OD-007 "outstanding quantity = requested quantity − fulfilled quantity".
  def outstanding_quantity
    [ requested_quantity - fulfilled_quantity, 0 ].max
  end

  def active_reserved_quantity
    request_held_reserved_quantity + pos_held_reserved_quantity
  end

  # Reservations still sourced to this request (in-house hold / receipt conversion).
  def request_held_reserved_quantity
    InventoryReservation.active.where(source_type: "product_request", source_id: id).sum(:quantity)
  end

  # Reservations transferred onto open POS lines that still fulfil this request.
  # Coverage must include these while the transaction remains open or suspended.
  def pos_held_reserved_quantity
    InventoryReservation.active
      .where(source_type: "pos_line_item")
      .joins("INNER JOIN pos_line_items ON pos_line_items.id = inventory_reservations.source_id")
      .where(pos_line_items: { product_request_id: id, status: "pending" })
      .sum("inventory_reservations.quantity")
  end

  def remaining_allocated_quantity
    purchase_order_allocations.includes(:purchase_order_allocation_events).sum(&:remaining_quantity)
  end

  # OD-007 "uncovered quantity = requested − fulfilled − active reservations
  # − remaining allocations"; must never be negative.
  def uncovered_quantity
    [ requested_quantity - fulfilled_quantity - active_reserved_quantity - remaining_allocated_quantity, 0 ].max
  end

  # Absolute committed supply that must not exceed requested quantity after an
  # edit: fulfilled + active reserved + remaining allocated (before clamping).
  def covered_quantity
    fulfilled_quantity + active_reserved_quantity + remaining_allocated_quantity
  end

  # Supply/fulfilment against a Product Request always requires the Variant's
  # Product to match the request. When the request already has a resolved
  # Variant, that exact Variant is required as well.
  def compatible_with_variant?(variant)
    return false if variant.blank?

    return false unless variant.product_id == product_id
    return true if product_variant_id.blank?

    product_variant_id == variant.id
  end

  def compatibility_error_for(variant)
    return "product variant is required" if variant.blank?
    return "product variant must belong to the requested product" unless variant.product_id == product_id
    return "product variant must match the request's resolved variant" if product_variant_id.present? && product_variant_id != variant.id

    nil
  end

  private

  def resolved_quantity_within_requested
    return if resolved_quantity.nil? || requested_quantity.nil?
    return if resolved_quantity <= requested_quantity

    errors.add(:resolved_quantity, "must not exceed requested quantity")
  end

  def product_belongs_to_store_organization
    return if store.blank? || product.blank?
    return if store.organization_id == product.organization_id

    errors.add(:product, "must belong to the same organization as the store")
  end

  def variant_matches_product
    return if product_variant.blank? || product.blank?
    return if product_variant.product_id == product.id

    errors.add(:product_variant, "must belong to the requested product")
  end

  def supersedes_within_same_store
    return if supersedes_product_request.blank? || store.blank?
    return if supersedes_product_request.store_id == store.id

    errors.add(:supersedes_product_request, "must belong to the same store")
  end

  def supersedes_not_self
    return if supersedes_product_request_id.blank?
    return if supersedes_product_request_id != id

    errors.add(:supersedes_product_request, "cannot supersede itself")
  end
end
