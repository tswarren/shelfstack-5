# frozen_string_literal: true

# Independent approval record (ADR-0011): requester and approver authenticate with
# their own credentials; the approving identity, reason, and authority-limit context
# are retained. Created by Pos::AuthorizeAction when a requester's authority or
# permission is insufficient and an approver satisfies the action on their behalf.
class PosApproval < ApplicationRecord
  ACTION_TYPES = %w[
    price_override discount_apply tax_exemption tax_category_override cash_movement
    post_void stored_value_adjustment stored_value_refund_exception card_refund_reconciliation
    reconciliation_variance
  ].freeze
  # card_refund_reconciliation retained for schema check compatibility; unused after Phase 6 simplification.
  SELF_APPROVAL_ACTION_TYPES = %w[post_void stored_value_adjustment reconciliation_variance].freeze

  belongs_to :store
  belongs_to :pos_session, optional: true
  belongs_to :pos_transaction, optional: true
  belongs_to :pos_line_item, optional: true
  belongs_to :requested_by_user, class_name: "User"
  belongs_to :approved_by_user, class_name: "User"

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :reason, presence: true
  validates :approved_at, presence: true
  validate :approver_differs_from_requester

  private

  def approver_differs_from_requester
    return if requested_by_user_id.blank? || approved_by_user_id.blank?
    return if requested_by_user_id != approved_by_user_id
    return if SELF_APPROVAL_ACTION_TYPES.include?(action_type)

    errors.add(:approved_by_user, "must be a different user than the requester")
  end
end
