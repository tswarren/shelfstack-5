# frozen_string_literal: true

module Pos
  class CloseSession < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_session, :pos_session_z_report, :success?, :error, :replayed)

    def initialize(pos_session:, actor:, counted_cash_cents: nil, card_evidence: nil)
      @pos_session = pos_session
      @actor = actor
      @counted_cash_cents = counted_cash_cents
      @card_evidence = card_evidence
    end

    def call
      store = @pos_session.store
      unless @actor.can?("pos.session.close", store: store)
        return failure("missing permission pos.session.close")
      end

      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)

        if session.closed?
          return Result.new(
            pos_session: session,
            pos_session_z_report: session.pos_session_z_report,
            success?: true,
            error: nil,
            replayed: true
          )
        end

        if PosTransaction.where(active_pos_session_id: session.id, status: "open").exists?
          raise Error, "cannot close session while it controls an open transaction"
        end

        if session.cash_enabled?
          closing = resolve_closing_count!(session)
          expected = Pos::CalculateExpectedCash.call(pos_session: session).expected_cash_cents
          session.update!(
            status: "closed",
            closed_at: Time.current,
            closed_by_user: @actor,
            expected_cash_cents: expected,
            counted_cash_cents: closing.total_cents,
            cash_variance_cents: closing.total_cents - expected
          )
        else
          session.update!(status: "closed", closed_at: Time.current, closed_by_user: @actor)
        end

        record_session_card_evidence!(session) if session_card_evidence_required?(session)

        cutoff = session.closed_at
        totals = Reporting::BuildSessionTotals.call(pos_session: session, source_cutoff_at: cutoff)
        z_report = persist_session_z!(session, totals, cutoff)
        audit_z_created!(session, z_report)

        Result.new(
          pos_session: session,
          pos_session_z_report: z_report,
          success?: true,
          error: nil,
          replayed: false
        )
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      failure(e.message)
    end

    private

    def failure(message)
      Result.new(
        pos_session: @pos_session,
        pos_session_z_report: nil,
        success?: false,
        error: message,
        replayed: false
      )
    end

    def resolve_closing_count!(session)
      existing_closing = PosSessionCashCount.find_by(pos_session_id: session.id, count_type: "closing")
      latest = PosSessionCashCount
        .where(pos_session_id: session.id, count_type: %w[closing manager_recount])
        .order(:id)
        .last
      now = Time.current

      if @counted_cash_cents.nil?
        raise Error, "closing cash count is required before closing a cash-enabled session" if latest.blank?

        return latest
      end

      counted = @counted_cash_cents.to_i
      raise Error, "counted cash must not be negative" if counted.negative?

      if existing_closing.nil?
        PosSessionCashCount.create!(
          pos_session: session,
          count_type: "closing",
          total_cents: counted,
          counted_by_user: @actor,
          counted_at: now,
          created_at: now
        )
      elsif latest.total_cents != counted
        PosSessionCashCount.create!(
          pos_session: session,
          count_type: "manager_recount",
          total_cents: counted,
          counted_by_user: @actor,
          counted_at: now,
          created_at: now
        )
      else
        latest
      end
    end

    def session_card_evidence_required?(session)
      return false unless session.store.card_reconciliation_grain == "session"
      return false unless session_has_card_tenders?(session)

      true
    end

    def session_has_card_tenders?(session)
      PosTender
        .joins(:tender_type, :pos_transaction)
        .where(pos_transactions: { completed_pos_session_id: session.id, status: "completed" })
        .where(status: "completed", removed_at: nil)
        .where(tender_types: { tender_category: "card" })
        .exists?
    end

    def record_session_card_evidence!(session)
      evidence = @card_evidence || {}
      mode = evidence[:mode].to_s.presence || evidence["mode"].to_s.presence

      case mode
      when "unavailable"
        reason = evidence[:unavailable_reason].presence || evidence["unavailable_reason"].presence
        raise Error, "card evidence unavailable reason is required" if reason.blank?
        unless @actor.can?("reporting.close_evidence_unavailable", store: session.store)
          raise Error, "missing permission reporting.close_evidence_unavailable"
        end

        PosCloseCardEvidence.create!(
          store: session.store,
          pos_session: session,
          kind: "merchant_slip",
          status: "unavailable",
          unavailable_reason: reason,
          entered_by_user: @actor,
          entered_at: Time.current
        )
        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: session.store.organization,
          store: session.store,
          action: "pos_session.card_evidence_unavailable",
          subject: session,
          metadata: { "reason" => reason }
        )
      when "recorded", nil, ""
        net = evidence[:net_cents].presence || evidence["net_cents"].presence
        raise Error, "session merchant-slip card evidence is required" if net.nil?

        PosCloseCardEvidence.create!(
          store: session.store,
          pos_session: session,
          kind: "merchant_slip",
          status: "recorded",
          precision: "net_only",
          net_cents: net.to_i,
          terminal_reference: evidence[:terminal_reference].presence || evidence["terminal_reference"],
          entered_by_user: @actor,
          entered_at: Time.current
        )
      else
        raise Error, "invalid card evidence mode"
      end
    end

    def persist_session_z!(session, totals, cutoff)
      store = Store.lock.find(session.store_id)
      z_number = store.next_session_z_number
      store.update!(next_session_z_number: z_number + 1)

      PosSessionZReport.create!(
        pos_session: session,
        store: store,
        z_number: z_number,
        business_date: session.business_day.reporting_date,
        source_cutoff_at: cutoff,
        report_definition_version: totals.report_definition_version,
        generated_at: cutoff,
        generated_by_user: @actor,
        payload: totals.to_payload,
        expected_cash_cents: totals.cash["expected_cash_cents"],
        counted_cash_cents: totals.cash["counted_cash_cents"],
        cash_variance_cents: totals.cash["cash_variance_cents"]
      )
    end

    def audit_z_created!(session, z_report)
      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: session.store.organization,
        store: session.store,
        action: "pos_session_z_report.created",
        subject: z_report,
        metadata: {
          "pos_session_id" => session.id,
          "z_number" => z_report.z_number,
          "report_definition_version" => z_report.report_definition_version
        }
      )
    end
  end
end
