# frozen_string_literal: true

class PosCloseCardEvidence < ApplicationRecord
  KINDS = %w[merchant_slip machine_batch].freeze
  STATUSES = %w[recorded unavailable].freeze
  PRECISIONS = %w[net_only received_and_refunded].freeze

  belongs_to :store
  belongs_to :pos_session, optional: true
  belongs_to :business_day, optional: true
  belongs_to :entered_by_user, class_name: "User"

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :entered_at, presence: true
  validate :exactly_one_scope
  validate :status_shape

  before_destroy :prevent_destroy
  before_update :prevent_mutation

  private

  def exactly_one_scope
    if pos_session_id.present? == business_day_id.present?
      errors.add(:base, "exactly one of pos_session or business_day is required")
    end
  end

  def status_shape
    case status
    when "unavailable"
      errors.add(:unavailable_reason, "can't be blank") if unavailable_reason.blank?
      errors.add(:precision, "must be blank") if precision.present?
      errors.add(:net_cents, "must be blank") if net_cents.present?
    when "recorded"
      errors.add(:unavailable_reason, "must be blank") if unavailable_reason.present?
      errors.add(:precision, "is not included in the list") unless PRECISIONS.include?(precision)
      if precision == "net_only" && net_cents.nil?
        errors.add(:net_cents, "can't be blank")
      end
      if precision == "received_and_refunded"
        errors.add(:received_cents, "can't be blank") if received_cents.nil?
        errors.add(:refunded_cents, "can't be blank") if refunded_cents.nil?
        errors.add(:net_cents, "can't be blank") if net_cents.nil?
        if received_cents.present? && refunded_cents.present? && net_cents.present?
          expected = received_cents - refunded_cents
          errors.add(:net_cents, "must equal received minus refunded") unless net_cents == expected
        end
      end
    end
  end

  def prevent_destroy
    raise ActiveRecord::ReadOnlyRecord, "close card evidence is immutable"
  end

  def prevent_mutation
    raise ActiveRecord::ReadOnlyRecord, "close card evidence is immutable"
  end
end
