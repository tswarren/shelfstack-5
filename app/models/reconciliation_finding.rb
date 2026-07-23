# frozen_string_literal: true

class ReconciliationFinding < ApplicationRecord
  belongs_to :reconciliation_comparison
  belongs_to :recorded_by_user, class_name: "User"

  validates :category, :explanation, :recorded_at, presence: true
end
