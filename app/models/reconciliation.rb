# frozen_string_literal: true

class Reconciliation < ApplicationRecord
  SCOPE_TYPES = %w[session business_day].freeze
  STATUSES = %w[draft finalized].freeze

  belongs_to :store
  belongs_to :pos_session, optional: true
  belongs_to :business_day, optional: true
  belongs_to :opened_by_user, class_name: "User"
  belongs_to :reconciled_by_user, class_name: "User", optional: true
  has_many :reconciliation_comparisons, dependent: :restrict_with_exception
  has_many :reconciliation_resolutions, dependent: :restrict_with_exception

  validates :scope_type, presence: true, inclusion: { in: SCOPE_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opened_at, presence: true
  validates :pos_session_id, uniqueness: true, allow_nil: true
  validates :business_day_id, uniqueness: true, allow_nil: true
  validate :scope_shape
  validate :finalize_shape

  before_update :prevent_finalized_mutation
  before_destroy :prevent_finalized_destroy

  def draft?
    status == "draft"
  end

  def finalized?
    status == "finalized"
  end

  private

  def scope_shape
    case scope_type
    when "session"
      errors.add(:pos_session, "can't be blank") if pos_session_id.blank?
      errors.add(:business_day, "must be blank for session scope") if business_day_id.present?
    when "business_day"
      errors.add(:business_day, "can't be blank") if business_day_id.blank?
      errors.add(:pos_session, "must be blank for business_day scope") if pos_session_id.present?
    end
  end

  def finalize_shape
    if status == "finalized"
      errors.add(:reconciled_at, "can't be blank") if reconciled_at.blank?
      errors.add(:reconciled_by_user, "can't be blank") if reconciled_by_user_id.blank?
    else
      errors.add(:reconciled_at, "must be blank while draft") if reconciled_at.present?
      errors.add(:reconciled_by_user, "must be blank while draft") if reconciled_by_user_id.present?
    end
  end

  def prevent_finalized_mutation
    return unless status_in_database == "finalized"

    errors.add(:base, "cannot change a finalized reconciliation")
    throw :abort
  end

  def prevent_finalized_destroy
    return unless status_in_database == "finalized" || finalized?

    errors.add(:base, "cannot destroy a finalized reconciliation")
    throw :abort
  end
end
