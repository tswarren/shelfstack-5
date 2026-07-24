# frozen_string_literal: true

module Reporting
  class RecordReconciliationResolution < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:resolution, :success?, :error)

    NUMERIC_RESOLUTION_TYPES = %w[
      explained_no_correction
      accepted_variance
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

        validate_comparison_required!
        validate_resolution_for_comparison!
        validate_ownership!(recon)
        validate_no_supersede!
        validate_no_conflicting_active_resolution!

        if @explanation.blank?
          raise Error, "explanation is required"
        end

        resolution = ReconciliationResolution.create!(
          reconciliation: recon,
          reconciliation_comparison: @comparison,
          resolution_type: @resolution_type,
          explanation: @explanation,
          supersedes_resolution: nil,
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
            "comparison_id" => @comparison.id
          }
        )

        Result.new(resolution: resolution, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(resolution: nil, success?: false, error: e.message)
    end

    private

    def validate_comparison_required!
      raise Error, "comparison is required" if @comparison.nil?
    end

    def validate_resolution_for_comparison!
      if @resolution_type == "unresolved"
        raise Error, "unresolved resolutions are not recorded; use Review later to leave the draft open"
      end
      if @resolution_type == "linked_domain_correction"
        raise Error, "linked domain correction is not available until correction linking is implemented"
      end

      if @comparison.observed_unavailable
        unless @resolution_type == "accept_evidence_unavailable"
          raise Error, "unavailable evidence requires accept_evidence_unavailable"
        end
        return
      end

      if @comparison.variance_cents.to_i.nonzero?
        unless NUMERIC_RESOLUTION_TYPES.include?(@resolution_type)
          raise Error, "nonzero variance requires accepted_variance or explained_no_correction"
        end
        return
      end

      raise Error, "an exact comparison does not require a resolution"
    end

    def validate_ownership!(recon)
      unless @comparison.reconciliation_id == recon.id
        raise Error, "comparison does not belong to this reconciliation"
      end
    end

    def validate_no_supersede!
      return if @supersedes.nil?

      raise Error, "resolution superseding is not available yet; see deferred follow-up for append-only replace"
    end

    def validate_no_conflicting_active_resolution!
      active = @comparison.reconciliation_resolutions.where(superseded: false)
      raise Error, "comparison already has an active resolution" if active.exists?
    end
  end
end
