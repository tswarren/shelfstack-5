# frozen_string_literal: true

module Reporting
  class RecordReconciliationResolution < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:resolution, :success?, :error)

    def initialize(reconciliation:, actor:, resolution_type:, explanation: nil,
                   reconciliation_comparison: nil, supersedes_resolution: nil)
      @reconciliation = reconciliation
      @actor = actor
      @resolution_type = resolution_type
      @explanation = explanation
      @comparison = reconciliation_comparison
      @supersedes = supersedes_resolution
    end

    def call
      unless @actor.can?("reporting.record_reconciliation_resolution", store: @reconciliation.store)
        return Result.new(resolution: nil, success?: false, error: "missing permission reporting.record_reconciliation_resolution")
      end
      raise Error, "cannot resolve a finalized reconciliation without supersede" if @reconciliation.finalized? && @supersedes.nil?

      ActiveRecord::Base.transaction do
        if @supersedes
          @supersedes.update!(superseded: true)
        end

        resolution = ReconciliationResolution.create!(
          reconciliation: @reconciliation,
          reconciliation_comparison: @comparison,
          resolution_type: @resolution_type,
          explanation: @explanation,
          supersedes_resolution: @supersedes,
          recorded_by_user: @actor,
          recorded_at: Time.current
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @reconciliation.store.organization,
          store: @reconciliation.store,
          action: "reconciliation.resolution_recorded",
          subject: resolution,
          metadata: {
            "resolution_type" => resolution.resolution_type,
            "reconciliation_id" => @reconciliation.id
          }
        )

        Result.new(resolution: resolution, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(resolution: nil, success?: false, error: e.message)
    end
  end
end
