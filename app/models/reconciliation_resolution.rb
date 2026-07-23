# frozen_string_literal: true

class ReconciliationResolution < ApplicationRecord
  RESOLUTION_TYPES = %w[
    explained_no_correction
    accepted_variance
    linked_domain_correction
    unresolved
    accept_evidence_unavailable
  ].freeze

  belongs_to :reconciliation
  belongs_to :reconciliation_comparison, optional: true
  belongs_to :supersedes_resolution, class_name: "ReconciliationResolution", optional: true
  belongs_to :recorded_by_user, class_name: "User"
  has_many :superseding_resolutions, class_name: "ReconciliationResolution",
           foreign_key: :supersedes_resolution_id, inverse_of: :supersedes_resolution,
           dependent: :restrict_with_exception

  validates :resolution_type, presence: true, inclusion: { in: RESOLUTION_TYPES }
  validates :recorded_at, presence: true
end
