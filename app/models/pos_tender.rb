# frozen_string_literal: true

class PosTender < ApplicationRecord
  DIRECTIONS = %w[received refunded].freeze
  STATUSES = %w[pending authorized completed voided removed].freeze
  # Statuses that lock commercial editing on the owning Transaction (domain "Tender-state lock").
  UNRESOLVED_STATUSES = %w[pending authorized].freeze

  belongs_to :pos_transaction
  belongs_to :store
  belongs_to :tender_type
  belongs_to :created_by_user, class_name: "User"
  belongs_to :voided_by_user, class_name: "User", optional: true
  belongs_to :removed_by_user, class_name: "User", optional: true

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :amount_tendered_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :change_due_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :store_matches_transaction

  scope :unresolved, -> { where(status: UNRESOLVED_STATUSES) }
  scope :settled, -> { where(status: "completed") }

  def pending?
    status == "pending"
  end

  def authorized?
    status == "authorized"
  end

  def completed?
    status == "completed"
  end

  def unresolved?
    UNRESOLVED_STATUSES.include?(status)
  end

  private

  def store_matches_transaction
    return if pos_transaction.blank? || store.blank?
    return if pos_transaction.store_id == store_id

    errors.add(:store, "must match the transaction's store")
  end
end
