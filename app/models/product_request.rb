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
