# frozen_string_literal: true

class PosCashMovement < ApplicationRecord
  belongs_to :store
  belongs_to :pos_session
  belongs_to :cash_movement_type
  belongs_to :created_by_user, class_name: "User"
  belongs_to :approved_by_user, class_name: "User", optional: true
  belongs_to :pos_approval, optional: true

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :store_matches_session

  private

  def store_matches_session
    return if pos_session.blank? || store.blank?
    return if pos_session.store_id == store_id

    errors.add(:store, "must match the session's store")
  end
end
