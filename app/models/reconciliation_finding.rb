# frozen_string_literal: true

class ReconciliationFinding < ApplicationRecord
  belongs_to :reconciliation_comparison
  belongs_to :recorded_by_user, class_name: "User"

  validates :category, :explanation, :recorded_at, presence: true

  before_create :reject_when_reconciliation_finalized!
  before_update :reject_when_reconciliation_finalized!
  before_destroy :reject_when_reconciliation_finalized!

  private

  def reject_when_reconciliation_finalized!
    return unless reconciliation_comparison&.reconciliation&.finalized?

    raise ActiveRecord::ReadOnlyRecord, "cannot modify findings on a finalized reconciliation"
  end
end

