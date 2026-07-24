# frozen_string_literal: true

class ReconciliationComparison < ApplicationRecord
  COMPARISON_TYPES = %w[session_cash session_merchant_slip day_machine_batch].freeze
  PRECISIONS = %w[net_only received_and_refunded].freeze

  belongs_to :reconciliation
  belongs_to :pos_close_card_evidence, optional: true
  has_many :reconciliation_findings, dependent: :restrict_with_exception
  has_many :reconciliation_resolutions, dependent: :restrict_with_exception

  validates :comparison_type, presence: true, inclusion: { in: COMPARISON_TYPES }
  validates :precision, inclusion: { in: PRECISIONS }, allow_nil: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :reconciliation_id }
  validate :unavailable_shape

  before_create :reject_when_reconciliation_finalized!
  before_update :reject_when_reconciliation_finalized!
  before_destroy :reject_when_reconciliation_finalized!

  private

  def unavailable_shape
    return unless observed_unavailable

    errors.add(:observed_cents, "must be blank when unavailable") if observed_cents.present?
    errors.add(:variance_cents, "must be blank when unavailable") if variance_cents.present?
  end

  def reject_when_reconciliation_finalized!
    return unless Reconciliation.where(id: reconciliation_id, status: "finalized").exists?

    raise ActiveRecord::ReadOnlyRecord, "cannot modify comparisons on a finalized reconciliation"
  end
end

