# frozen_string_literal: true

module Pos
  class CloseBusinessDay < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:business_day, :business_day_z_report, :success?, :error, :replayed)

    def initialize(business_day:, actor:, card_evidence: nil)
      @business_day = business_day
      @actor = actor
      @card_evidence = card_evidence
    end

    def call
      store = @business_day.store
      unless @actor.can?("pos.business_day.close", store: store)
        return failure("missing permission pos.business_day.close")
      end

      ActiveRecord::Base.transaction do
        business_day = BusinessDay.lock.find(@business_day.id)

        if business_day.closed?
          return Result.new(
            business_day: business_day,
            business_day_z_report: business_day.business_day_z_report,
            success?: true,
            error: nil,
            replayed: true
          )
        end

        if PosSession.where(business_day_id: business_day.id, status: "open").exists?
          raise Error, "cannot close business day while a POS session is open"
        end

        closed_sessions = PosSession.where(business_day_id: business_day.id, status: "closed")
        missing_z = closed_sessions.left_outer_joins(:pos_session_z_report)
          .where(pos_session_z_reports: { id: nil })
        if missing_z.exists?
          raise Error, "cannot close business day while a closed session lacks a Session Z report"
        end

        record_day_card_evidence!(business_day) if day_card_evidence_required?(business_day)

        business_day.update!(status: "closed", closed_at: Time.current, closed_by_user: @actor)

        cutoff = business_day.closed_at
        totals = Reporting::BuildBusinessDayTotals.call(
          business_day: business_day,
          mode: :final,
          source_cutoff_at: cutoff
        )
        validate_day_totals!(business_day, totals)
        z_report = persist_day_z!(business_day, totals, cutoff)
        audit_z_created!(business_day, z_report)

        Result.new(
          business_day: business_day,
          business_day_z_report: z_report,
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
        business_day: @business_day,
        business_day_z_report: nil,
        success?: false,
        error: message,
        replayed: false
      )
    end

    def day_card_evidence_required?(business_day)
      PosTender
        .joins(:tender_type, pos_transaction: :completed_pos_session)
        .where(pos_sessions: { business_day_id: business_day.id }, pos_transactions: { status: "completed" })
        .where(status: "completed", removed_at: nil)
        .where(tender_types: { tender_category: "card" })
        .exists?
    end

    def record_day_card_evidence!(business_day)
      evidence = @card_evidence || {}
      mode = evidence[:mode].to_s.presence || evidence["mode"].to_s.presence

      case mode
      when "unavailable"
        reason = evidence[:unavailable_reason].presence || evidence["unavailable_reason"].presence
        raise Error, "card evidence unavailable reason is required" if reason.blank?
        unless @actor.can?("reporting.close_evidence_unavailable", store: business_day.store)
          raise Error, "missing permission reporting.close_evidence_unavailable"
        end

        PosCloseCardEvidence.create!(
          store: business_day.store,
          business_day: business_day,
          kind: "machine_batch",
          status: "unavailable",
          unavailable_reason: reason,
          entered_by_user: @actor,
          entered_at: Time.current
        )
        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: business_day.store.organization,
          store: business_day.store,
          action: "business_day.card_evidence_unavailable",
          subject: business_day,
          metadata: { "reason" => reason }
        )
      when "recorded", nil, ""
        net = evidence[:net_cents].presence || evidence["net_cents"].presence
        raise Error, "business-day machine/batch card evidence is required" if net.nil?

        PosCloseCardEvidence.create!(
          store: business_day.store,
          business_day: business_day,
          kind: "machine_batch",
          status: "recorded",
          precision: "net_only",
          net_cents: net.to_i,
          batch_reference: evidence[:batch_reference].presence || evidence["batch_reference"],
          entered_by_user: @actor,
          entered_at: Time.current
        )
      else
        raise Error, "invalid card evidence mode"
      end
    end

    def validate_day_totals!(business_day, totals)
      activity = Reporting::BuildBusinessDayTotals.call(
        business_day: business_day,
        mode: :activity_rebuild,
        source_cutoff_at: business_day.closed_at
      )
      mismatches = day_totals_component_mismatches(totals, activity)
      return if mismatches.empty?

      raise Error, "Day Z consolidation does not match completed day activity (#{mismatches.join(', ')})"
    end

    def day_totals_component_mismatches(final_totals, activity)
      checks = {
        "gross_sales_cents" => [ final_totals.commercial["gross_sales_cents"], activity.commercial["gross_sales_cents"] ],
        "discount_total_cents" => [ final_totals.commercial["discount_total_cents"], activity.commercial["discount_total_cents"] ],
        "return_total_cents" => [ final_totals.commercial["return_total_cents"], activity.commercial["return_total_cents"] ],
        "post_void_commercial_effect_cents" => [
          final_totals.commercial["post_void_commercial_effect_cents"],
          activity.commercial["post_void_commercial_effect_cents"]
        ],
        "net_sales_cents" => [ final_totals.commercial["net_sales_cents"], activity.commercial["net_sales_cents"] ],
        "net_tax_cents" => [ final_totals.settlement["net_tax_cents"], activity.settlement["net_tax_cents"] ],
        "stored_value_funded_cents" => [
          final_totals.settlement["stored_value_issued_reloaded_cents"],
          activity.settlement["stored_value_issued_reloaded_cents"]
        ],
        "transaction_total_cents" => [
          final_totals.settlement["transaction_total_cents"],
          activity.settlement["transaction_total_cents"]
        ],
        "net_tenders_cents" => [
          final_totals.settlement["net_tenders_cents"],
          activity.settlement["net_tenders_cents"]
        ],
        "completed_transactions" => [
          final_totals.activity_counts["completed_transactions"],
          activity.activity_counts["completed_transactions"]
        ]
      }
      checks.filter_map do |key, (left, right)|
        key if left.to_i != right.to_i
      end
    end

    def persist_day_z!(business_day, totals, cutoff)
      store = Store.lock.find(business_day.store_id)
      z_number = store.next_business_day_z_number
      store.update!(next_business_day_z_number: z_number + 1)

      payload = totals.to_payload
      payload["card_evidence"] = business_day.pos_close_card_evidences.order(:id).map do |row|
        {
          "kind" => row.kind,
          "status" => row.status,
          "precision" => row.precision,
          "net_cents" => row.net_cents,
          "batch_reference" => row.batch_reference,
          "unavailable_reason" => row.unavailable_reason
        }
      end

      BusinessDayZReport.create!(
        business_day: business_day,
        store: store,
        z_number: z_number,
        business_date: business_day.reporting_date,
        source_cutoff_at: cutoff,
        report_definition_version: totals.report_definition_version,
        generated_at: cutoff,
        generated_by_user: @actor,
        payload: payload
      )
    end

    def audit_z_created!(business_day, z_report)
      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: business_day.store.organization,
        store: business_day.store,
        action: "business_day_z_report.created",
        subject: z_report,
        metadata: {
          "business_day_id" => business_day.id,
          "z_number" => z_report.z_number,
          "report_definition_version" => z_report.report_definition_version
        }
      )
    end
  end
end
