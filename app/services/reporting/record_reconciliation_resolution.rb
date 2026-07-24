# frozen_string_literal: true

module Reporting
  class RecordReconciliationResolution < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:resolution, :success?, :error)

    MVP_RESOLUTION_TYPES = %w[
      explained_no_correction
      accepted_variance
      accept_evidence_unavailable
    ].freeze

    def initialize(reconciliation:, actor:, resolution_type:, explanation: nil,
                   reconciliation_comparison: nil, supersedes_resolution: nil)
      @reconciliation = reconciliation
      @actor = actor
      @resolution_type = resolution_type.to_s
      @explanation = explanation
      @comparison = reconciliation_comparison
      @supersedes = supersedes_resolution
    end

    def call
      unless @actor.can?("reporting.record_reconciliation_resolution", store: @reconciliation.store)
        return Result.new(resolution: nil, success?: false, error: "missing permission reporting.record_reconciliation_resolution")
      end

      ActiveRecord::Base.transaction do
        recon = Reconciliation.lock.find(@reconciliation.id)
        raise Error, "cannot change a finalized reconciliation" if recon.finalized?

        validate_resolution_type!
        validate_ownership!(recon)
        validate_no_conflicting_active_resolution!

        if @supersedes
          @supersedes.update!(superseded: true)
        end

        if @explanation.blank?
          raise Error, "explanation is required"
        end

        resolution = ReconciliationResolution.create!(
          reconciliation: recon,
          reconciliation_comparison: @comparison,
          resolution_type: @resolution_type,
          explanation: @explanation,
          supersedes_resolution: @supersedes,
          recorded_by_user: @actor,
          recorded_at: Time.current
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: recon.store.organization,
          store: recon.store,
          action: "reconciliation.resolution_recorded",
          subject: resolution,
          metadata: {
            "resolution_type" => resolution.resolution_type,
            "reconciliation_id" => recon.id,
            "comparison_id" => @comparison&.id
          }
        )

        Result.new(resolution: resolution, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(resolution: nil, success?: false, error: e.message)
    end

    private

    def validate_resolution_type!
      if @resolution_type == "unresolved"
        raise Error, "unresolved resolutions are not recorded; use Review later to leave the draft open"
      end
      if @resolution_type == "linked_domain_correction"
        raise Error, "linked domain correction is not available until correction linking is implemented"
      end
      return if MVP_RESOLUTION_TYPES.include?(@resolution_type)

      raise Error, "unsupported resolution type #{@resolution_type}"
    end

    def validate_ownership!(recon)
      if @comparison
        unless @comparison.reconciliation_id == recon.id
          raise Error, "comparison does not belong to this reconciliation"
        end
      end

      return unless @supersedes

      unless @supersedes.reconciliation_id == recon.id
        raise Error, "superseded resolution does not belong to this reconciliation"
      end
      if @comparison && @supersedes.reconciliation_comparison_id.present? &&
          @supersedes.reconciliation_comparison_id != @comparison.id
        raise Error, "superseded resolution does not apply to this comparison"
      end
    end

    def validate_no_conflicting_active_resolution!
      return if @comparison.nil?
      return if @supersedes.present?

      active = @comparison.reconciliation_resolutions.where(superseded: false)
      raise Error, "comparison already has an active resolution; supersede it explicitly" if active.exists?
    end
  end
end
