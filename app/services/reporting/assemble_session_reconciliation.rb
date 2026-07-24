# frozen_string_literal: true

module Reporting
  class AssembleSessionReconciliation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:reconciliation, :success?, :error)

    def initialize(pos_session:, actor:)
      @pos_session = pos_session
      @actor = actor
    end

    def call
      unless @actor.can?("reporting.reconcile_session", store: @pos_session.store)
        return Result.new(reconciliation: nil, success?: false, error: "missing permission reporting.reconcile_session")
      end
      session = PosSession.find(@pos_session.id)
      unless session.closed?
        return Result.new(reconciliation: nil, success?: false, error: "session must be closed before reconciliation")
      end
      @pos_session = session

      ActiveRecord::Base.transaction do
        recon = Reconciliation.find_or_initialize_by(pos_session_id: session.id)
        if recon.new_record?
          recon.assign_attributes(
            store: session.store,
            scope_type: "session",
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
          organization: session.store.organization,
          store: session.store,
          action: "reconciliation.session_assembled",
          subject: recon,
          metadata: { "pos_session_id" => session.id }
        )
        Result.new(reconciliation: recon, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(reconciliation: nil, success?: false, error: e.message)
    end

    private

    def ensure_comparisons!(recon)
      return if recon.reconciliation_comparisons.exists?

      position = 1
      if @pos_session.cash_enabled?
        expected = @pos_session.expected_cash_cents.to_i
        observed = @pos_session.counted_cash_cents.to_i
        recon.reconciliation_comparisons.create!(
          comparison_type: "session_cash",
          expected_cents: expected,
          observed_cents: observed,
          variance_cents: observed - expected,
          observed_unavailable: false,
          position: position
        )
        position += 1
      end

      if @pos_session.store.card_reconciliation_grain == "session"
        evidences = @pos_session.pos_close_card_evidences.order(:id).to_a
        create_aggregated_card_comparison!(recon, evidences, "session_merchant_slip", position) if evidences.any?
      end
    end

    def create_aggregated_card_comparison!(recon, evidences, type, position)
      statuses = evidences.map(&:status).uniq
      raise Error, "cannot mix recorded and unavailable card evidence in one scope" if statuses.size > 1

      if statuses == [ "unavailable" ]
        recon.reconciliation_comparisons.create!(
          comparison_type: type,
          observed_unavailable: true,
          external_reference: evidences.filter_map { |e| e.terminal_reference || e.batch_reference }.join(", ").presence,
          position: position
        )
        return
      end

      precisions = evidences.map { |e| e.precision.presence || "net_only" }.uniq
      raise Error, "cannot mix card evidence precisions in one scope" if precisions.size > 1
      raise Error, "received_and_refunded card evidence is not operable until its close workflow exists" if precisions.first == "received_and_refunded"

      expected = card_expected_net_cents
      observed = evidences.sum { |e| e.net_cents.to_i }
      recon.reconciliation_comparisons.create!(
        comparison_type: type,
        precision: "net_only",
        expected_cents: expected,
        observed_cents: observed,
        variance_cents: observed - expected,
        observed_unavailable: false,
        external_reference: evidences.filter_map { |e| e.terminal_reference || e.batch_reference }.join(", ").presence,
        position: position
      )
    end

    def card_expected_net_cents
      PosTender
        .joins(:tender_type, :pos_transaction)
        .where(pos_transactions: { completed_pos_session_id: @pos_session.id, status: "completed" })
        .where(status: "completed", removed_at: nil)
        .where(tender_types: { tender_category: "card" })
        .sum("CASE WHEN pos_tenders.direction = 'received' THEN pos_tenders.amount_cents ELSE -pos_tenders.amount_cents END")
    end
  end
end
