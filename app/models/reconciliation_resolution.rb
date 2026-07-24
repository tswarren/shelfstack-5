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

  before_create :reject_create_when_reconciliation_finalized!
  before_update :reject_mutation_when_reconciliation_finalized!
  before_destroy :reject_destroy_when_reconciliation_finalized!

  private

  def reject_create_when_reconciliation_finalized!
    return unless Reconciliation.where(id: reconciliation_id, status: "finalized").exists?

    raise ActiveRecord::ReadOnlyRecord, "cannot add resolutions to a finalized reconciliation"
  end

  def reject_mutation_when_reconciliation_finalized!
    return unless Reconciliation.where(id: reconciliation_id, status: "finalized").exists?

    raise ActiveRecord::ReadOnlyRecord, "cannot modify resolutions on a finalized reconciliation"
  end

  def reject_destroy_when_reconciliation_finalized!
    return unless Reconciliation.where(id: reconciliation_id, status: "finalized").exists?

    raise ActiveRecord::ReadOnlyRecord, "cannot delete resolutions on a finalized reconciliation"
  end
end
