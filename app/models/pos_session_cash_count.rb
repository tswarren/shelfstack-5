# frozen_string_literal: true

class PosSessionCashCount < ApplicationRecord
  COUNT_TYPES = %w[opening closing manager_recount reconciled].freeze

  belongs_to :pos_session
  belongs_to :counted_by_user, class_name: "User"

  validates :count_type, presence: true, inclusion: { in: COUNT_TYPES }
  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :counted_at, presence: true

  before_destroy :prevent_mutation
  before_update :prevent_mutation

  def readonly?
    !new_record?
  end

  private

  def prevent_mutation
    errors.add(:base, "session cash counts are append-only")
    throw(:abort)
  end
end
