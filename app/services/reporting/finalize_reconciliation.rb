# frozen_string_literal: true

module Reporting
  class FinalizeReconciliation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:reconciliation, :success?, :error)

    FINAL_RESOLUTION_TYPES = %w[
      accepted_variance
      explained_no_correction
    ].freeze

    def initialize(reconciliation:, actor:, approver: nil, approver_pin: nil, reason: nil)
      @reconciliation = reconciliation
      @actor = actor
      @approver = approver
      @approver_pin = approver_pin
      @reason = reason
    end

    def call
      permission = reconcile_permission
      unless @actor.can?(permission, store: @reconciliation.store)
        return Result.new(reconciliation: @reconciliation, success?: false, error: "missing permission #{permission}")
      end

      ActiveRecord::Base.transaction do
        recon = Reconciliation.lock.find(@reconciliation.id)
        return Result.new(reconciliation: recon, success?: true, error: nil) if recon.finalized?

        scope = recon.scope_type == "session" ? recon.pos_session : recon.business_day
        raise Error, "cannot finalize reconciliation while scope is open" if scope.open?

        if recon.scope_type == "business_day"
          pending = AssembleBusinessDayReconciliation.new(business_day: scope, actor: @actor)
            .pending_required_session_recons
          raise Error, "resolve pending session reconciliations first" if pending.any?
        end

        comparisons = recon.reconciliation_comparisons.includes(:reconciliation_resolutions).to_a
        if comparisons.empty? && recon.scope_type == "session"
          raise Error, "reconciliation has no comparisons"
        end

        comparisons.each { |comparison| validate_comparison_ready!(comparison) }

        numeric = comparisons.reject(&:observed_unavailable)
        max_abs_variance = numeric.map { |c| c.variance_cents.to_i.abs }.max || 0
        authorize_variance!(recon, max_abs_variance, permission) if max_abs_variance.positive?

        now = Time.current
        recon.update!(
          status: "finalized",
          reconciled_at: now,
          reconciled_by_user: @actor
        )

        if recon.scope_type == "session"
          recon.pos_session.update!(reconciled_at: now, reconciled_by_user: @actor)
        else
          recon.business_day.update!(reconciled_at: now, reconciled_by_user: @actor)
        end

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: recon.store.organization,
          store: recon.store,
          action: "reconciliation.finalized",
          subject: recon,
          metadata: {
            "scope_type" => recon.scope_type,
            "max_abs_variance_cents" => max_abs_variance
          }
        )

        Result.new(reconciliation: recon, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(reconciliation: @reconciliation, success?: false, error: e.message)
    end

    private

    def reconcile_permission
      @reconciliation.scope_type == "session" ? "reporting.reconcile_session" : "reporting.reconcile_business_day"
    end

    def validate_comparison_ready!(comparison)
      active = comparison.reconciliation_resolutions.reject(&:superseded)

      if comparison.observed_unavailable
        unless active.any? { |r| r.resolution_type == "accept_evidence_unavailable" }
          raise Error, "unavailable evidence must be accepted before finalize"
        end
        return
      end

      return if comparison.variance_cents.to_i.zero?

      if active.any? { |r| r.resolution_type == "unresolved" }
        raise Error, "unresolved comparisons cannot be finalized"
      end

      final = active.find { |r| FINAL_RESOLUTION_TYPES.include?(r.resolution_type) }
      raise Error, "nonzero variance requires an explained final resolution" if final.nil?
      raise Error, "final resolution requires an explanation" if final.explanation.blank?
    end

    def authorize_variance!(recon, abs_variance, permission)
      auth = Pos::AuthorizeAction.call(
        store: recon.store,
        requester: @actor,
        permission_key: permission,
        action_type: "reconciliation_variance",
        reason: @reason.presence || "Accept reconciliation variance of #{abs_variance} cents",
        limit_key: :cash_variance_review_threshold_cents,
        requested_value: abs_variance,
        approver: @approver,
        approver_pin: @approver_pin,
        approver_permission_key: "reporting.reconcile.approve",
        self_approver_permission_key: "reporting.reconcile.approve_self",
        pos_session: recon.pos_session
      )
      raise Error, auth.error || "variance authorization failed" unless auth.allowed?
    end
  end
end
