# frozen_string_literal: true

module Reporting
  class AssembleBusinessDayReconciliation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:reconciliation, :success?, :error)

    def initialize(business_day:, actor:)
      @business_day = business_day
      @actor = actor
    end

    def call
      unless @actor.can?("reporting.reconcile_business_day", store: @business_day.store)
        return Result.new(reconciliation: nil, success?: false, error: "missing permission reporting.reconcile_business_day")
      end
      business_day = BusinessDay.find(@business_day.id)
      unless business_day.closed?
        return Result.new(reconciliation: nil, success?: false, error: "business day must be closed before reconciliation")
      end
      @business_day = business_day

      pending = pending_required_session_recons
      if pending.any?
        return Result.new(
          reconciliation: nil,
          success?: false,
          error: "resolve pending session reconciliations first (#{pending.size} remaining)"
        )
      end

      ActiveRecord::Base.transaction do
        recon = Reconciliation.find_or_initialize_by(business_day_id: business_day.id)
        if recon.new_record?
          recon.assign_attributes(
            store: business_day.store,
            scope_type: "business_day",
            status: "draft",
            opened_at: Time.current,
            opened_by_user: @actor
          )
          recon.save!
        elsif recon.finalized?
          return Result.new(reconciliation: recon, success?: true, error: nil)
        end

        ensure_comparisons!(recon)
        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: business_day.store.organization,
          store: business_day.store,
          action: "reconciliation.business_day_assembled",
          subject: recon,
          metadata: { "business_day_id" => business_day.id }
        )
        Result.new(reconciliation: recon, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(reconciliation: nil, success?: false, error: e.message)
    end

    def pending_required_session_recons
      sessions = @business_day.pos_sessions.where(status: "closed")
      sessions.reject do |session|
        next true unless SessionReconciliationRequirement.required?(session)

        session.reconciliation&.finalized?
      end
    end

    private

    def ensure_comparisons!(recon)
      return if recon.reconciliation_comparisons.exists?

      evidences = @business_day.pos_close_card_evidences.order(:id).to_a
      return if evidences.empty?

      create_aggregated_card_comparison!(recon, evidences)
    end

    def create_aggregated_card_comparison!(recon, evidences)
      statuses = evidences.map(&:status).uniq
      raise Error, "cannot mix recorded and unavailable card evidence in one scope" if statuses.size > 1

      if statuses == [ "unavailable" ]
        recon.reconciliation_comparisons.create!(
          comparison_type: "day_machine_batch",
          observed_unavailable: true,
          external_reference: evidences.filter_map(&:batch_reference).join(", ").presence,
          position: 1
        )
        return
      end

      precisions = evidences.map { |e| e.precision.presence || "net_only" }.uniq
      raise Error, "cannot mix card evidence precisions in one scope" if precisions.size > 1
      raise Error, "received_and_refunded card evidence is not operable until its close workflow exists" if precisions.first == "received_and_refunded"

      expected = day_card_expected_net_cents
      observed = evidences.sum { |e| e.net_cents.to_i }
      recon.reconciliation_comparisons.create!(
        comparison_type: "day_machine_batch",
        precision: "net_only",
        expected_cents: expected,
        observed_cents: observed,
        variance_cents: observed - expected,
        observed_unavailable: false,
        external_reference: evidences.filter_map(&:batch_reference).join(", ").presence,
        position: 1
      )
    end

    def day_card_expected_net_cents
      PosTender
        .joins(:tender_type, pos_transaction: :completed_pos_session)
        .where(pos_sessions: { business_day_id: @business_day.id }, pos_transactions: { status: "completed" })
        .where(status: "completed", removed_at: nil)
        .where(tender_types: { tender_category: "card" })
        .sum("CASE WHEN pos_tenders.direction = 'received' THEN pos_tenders.amount_cents ELSE -pos_tenders.amount_cents END")
    end
  end
end
