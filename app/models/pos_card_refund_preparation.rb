# frozen_string_literal: true

# Durable card-refund preparation that binds terminal authorization to a
# server-owned plan. While status is `prepared`, the owning transaction is
# commercially locked (see PosTransaction#editable?). TTL (`expires_at`) is
# UI/staleness only — it never auto-abandons or unblocks the transaction.
class PosCardRefundPreparation < ApplicationRecord
  STATUSES = %w[prepared recorded_tender recorded_orphan abandoned].freeze
  FINGERPRINT_VERSION = 1
  TTL = 30.minutes

  TENDER_RESOLUTION_KINDS = %w[externally_voided validated_and_accepted replaced].freeze
  ORPHAN_RESOLUTION_KINDS = %w[
    external_void_confirmed linked_to_correcting_transaction accepted_financial_exception
  ].freeze

  belongs_to :pos_transaction
  belongs_to :tender_type
  belongs_to :intended_original_pos_tender, class_name: "PosTender", optional: true
  belongs_to :pos_approval, optional: true
  belongs_to :pos_tender, optional: true
  belongs_to :prepared_by_user, class_name: "User"
  belongs_to :recorded_by_user, class_name: "User", optional: true
  belongs_to :abandoned_by_user, class_name: "User", optional: true
  belongs_to :resolved_by_user, class_name: "User", optional: true
  belongs_to :correcting_pos_transaction, class_name: "PosTransaction", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :plan_fingerprint, :expires_at, presence: true
  validates :fingerprint_version, numericality: { only_integer: true, greater_than: 0 }

  scope :prepared, -> { where(status: "prepared") }
  scope :unresolved_orphans, -> {
    where(status: "recorded_orphan", resolved_at: nil)
  }

  def prepared?
    status == "prepared"
  end

  def recorded_tender?
    status == "recorded_tender"
  end

  def recorded_orphan?
    status == "recorded_orphan"
  end

  def abandoned?
    status == "abandoned"
  end

  def stale?
    prepared? && expires_at <= Time.current
  end

  def resolved?
    resolved_at.present?
  end

  def unresolved_orphan?
    recorded_orphan? && !resolved?
  end
end
