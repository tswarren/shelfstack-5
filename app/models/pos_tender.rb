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
  belongs_to :external_void_confirmed_by_user, class_name: "User", optional: true
  belongs_to :reverses_pos_tender, class_name: "PosTender", optional: true
  belongs_to :original_pos_tender, class_name: "PosTender", optional: true
  belongs_to :stored_value_account, optional: true
  has_one :post_void_reversing_tender, class_name: "PosTender", foreign_key: :reverses_pos_tender_id,
          inverse_of: :reverses_pos_tender, dependent: :restrict_with_exception
  has_many :refund_tenders, class_name: "PosTender", foreign_key: :original_pos_tender_id,
           inverse_of: :original_pos_tender, dependent: :restrict_with_exception
  has_many :stored_value_entries, dependent: :restrict_with_exception

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

  # Remaining amount that may still be refunded against this received tender.
  # A completed post-void reversing tender consumes the entire original amount.
  def remaining_refundable_cents
    return 0 unless direction == "received"
    return 0 if post_voided?

    prior = refund_tenders.where(status: %w[pending authorized completed]).sum(:amount_cents)
    amount_cents - prior
  end

  def post_voided?
    return true if post_void_reversing_tender&.completed?
    return true if pos_transaction&.post_void_transaction&.completed?

    false
  end

  private

  def store_matches_transaction
    return if pos_transaction.blank? || store.blank?
    return if pos_transaction.store_id == store_id

    errors.add(:store, "must match the transaction's store")
  end
end
