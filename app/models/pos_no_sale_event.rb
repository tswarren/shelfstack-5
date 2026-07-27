# frozen_string_literal: true

# Audited No Sale drawer-open event (INV-CASH-003). Not a cash movement.
class PosNoSaleEvent < ApplicationRecord
  REASON_MAX = 255

  belongs_to :organization
  belongs_to :store
  belongs_to :pos_session
  belongs_to :created_by_user, class_name: "User"

  validates :reason, presence: true, length: { maximum: REASON_MAX }
  validates :occurred_at, presence: true
  validates :idempotency_key, presence: true, uniqueness: { scope: :pos_session_id }
  validate :session_store_organization_consistency

  private

  def session_store_organization_consistency
    return if pos_session.blank? || store.blank? || organization.blank?

    errors.add(:store, "must match the POS session store") if pos_session.store_id != store_id
    errors.add(:organization, "must match the store organization") if store.organization_id != organization_id
  end
end
