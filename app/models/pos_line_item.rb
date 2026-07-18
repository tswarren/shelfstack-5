# frozen_string_literal: true

class PosLineItem < ApplicationRecord
  LINE_KINDS = %w[product open_ring].freeze
  STATUSES = %w[pending completed removed].freeze

  belongs_to :pos_transaction
  belongs_to :product_variant, optional: true
  belongs_to :department
  belongs_to :tax_category, optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :removed_by_user, class_name: "User", optional: true

  validates :line_kind, presence: true, inclusion: { in: LINE_KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :product_line_requires_variant
  validate :open_ring_forbids_variant
  validate :open_ring_requires_description_snapshot
  validate :department_is_postable

  scope :pending, -> { where(status: "pending") }

  def pending?
    status == "pending"
  end

  def removed?
    status == "removed"
  end

  def extended_price_cents
    quantity * unit_price_cents
  end

  def effective_description
    return description_snapshot if description_snapshot.present?
    return product_variant.product.name if line_kind == "product" && product_variant.present?

    department&.name
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
end
