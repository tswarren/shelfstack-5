# frozen_string_literal: true

module Reporting
  class BuildBusinessDayTotals < ApplicationService
    # mode: :live (Day X) mixes open-session live totals + closed Session Z payloads
    # mode: :final consolidates canonical Session Z snapshots only
    def initialize(business_day:, mode: :live, source_cutoff_at: Time.current)
      @business_day = business_day
      @mode = mode.to_sym
      @source_cutoff_at = source_cutoff_at
    end

    def call
      sessions = @business_day.pos_sessions.includes(:pos_session_z_report).order(:id)
      session_totals = sessions.map { |session| totals_for_session(session) }.compact

      commercial = sum_hashes(session_totals.map { |t| t.commercial })
      tax = merge_tax(session_totals.map(&:tax))
      stored_value = sum_hashes(session_totals.map(&:stored_value))
      tenders = merge_tenders(session_totals.map(&:tenders))
      settlement = merge_settlement(commercial, tax, stored_value, tenders)
      departments = merge_departments(session_totals.map(&:departments))
      activity = sum_hashes(session_totals.map(&:activity_counts))
      cash_summary = build_cash_summary(session_totals)
      breakdown = session_totals.map { |t| session_row(t) }

      BusinessDayTotals.new(
        report_definition_version: ReportDefinition::VERSION,
        business_day_id: @business_day.id,
        store_id: @business_day.store_id,
        business_date: @business_day.reporting_date,
        source_cutoff_at: @source_cutoff_at,
        mode: @mode.to_s,
        commercial: commercial,
        tax: tax,
        stored_value: stored_value,
        settlement: settlement,
        tenders: tenders,
        cash_summary: cash_summary,
        departments: departments,
        activity_counts: activity,
        session_breakdown: breakdown,
        exceptions: []
      )
    end

    private

    def totals_for_session(session)
      if session.closed? && session.pos_session_z_report.present?
        payload_to_session_totals(session.pos_session_z_report.payload)
      elsif @mode == :final
        nil
      else
        BuildSessionTotals.call(pos_session: session, source_cutoff_at: @source_cutoff_at)
      end
    end

    def payload_to_session_totals(payload)
      SessionTotals.new(
        report_definition_version: payload.fetch("report_definition_version"),
        pos_session_id: payload.fetch("pos_session_id"),
        store_id: payload.fetch("store_id"),
        business_day_id: payload.fetch("business_day_id"),
        business_date: Date.iso8601(payload.fetch("business_date")),
        source_cutoff_at: Time.iso8601(payload.fetch("source_cutoff_at")),
        commercial: payload.fetch("commercial"),
        tax: payload.fetch("tax"),
        stored_value: payload.fetch("stored_value"),
        settlement: payload.fetch("settlement"),
        tenders: payload.fetch("tenders"),
        cash: payload.fetch("cash"),
        departments: payload.fetch("departments"),
        activity_counts: payload.fetch("activity_counts"),
        exceptions: payload.fetch("exceptions", [])
      )
    end

    def session_row(totals)
      {
        "pos_session_id" => totals.pos_session_id,
        "net_sales_cents" => totals.commercial["net_sales_cents"],
        "net_tenders_cents" => totals.settlement["net_tenders_cents"],
        "cash_variance_cents" => totals.cash["cash_variance_cents"],
        "completed_transactions" => totals.activity_counts["completed_transactions"]
      }
    end

    def sum_hashes(hashes)
      return {} if hashes.empty?

      hashes.reduce({}) do |acc, hash|
        hash.each_with_object(acc) do |(key, value), memo|
          memo[key] = memo.fetch(key, 0) + value.to_i if value.is_a?(Numeric) || value.is_a?(String)
        end
      end
    end

    def merge_tax(taxes)
      components = taxes.flat_map { |t| t["components"] || [] }
                        .group_by { |c| c["receipt_code"] }
                        .map { |code, rows| { "receipt_code" => code, "amount_cents" => rows.sum { |r| r["amount_cents"].to_i } } }
      {
        "tax_total_cents" => taxes.sum { |t| t["tax_total_cents"].to_i },
        "components" => components
      }
    end

    def merge_tenders(tender_lists)
      rows = tender_lists.flatten
      rows.group_by { |r| r["tender_category"] }.map do |category, group|
        received = group.sum { |r| r["received_cents"].to_i }
        refunded = group.sum { |r| r["refunded_cents"].to_i }
        {
          "tender_category" => category,
          "received_cents" => received,
          "refunded_cents" => refunded,
          "net_cents" => received - refunded
        }
      end.sort_by { |row| row["tender_category"] }
    end

    def merge_settlement(commercial, tax, stored_value, tenders)
      net_sales = commercial["net_sales_cents"].to_i
      tax_total = tax["tax_total_cents"].to_i
      sv_liability = stored_value["issued_cents"].to_i + stored_value["reloaded_cents"].to_i
      transaction_total = net_sales + tax_total + sv_liability
      net_tenders = tenders.sum { |t| t["net_cents"].to_i }
      {
        "net_sales_cents" => net_sales,
        "net_tax_cents" => tax_total,
        "stored_value_issued_reloaded_cents" => sv_liability,
        "transaction_total_cents" => transaction_total,
        "net_tenders_cents" => net_tenders,
        "balanced" => transaction_total == net_tenders
      }
    end

    def merge_departments(lists)
      lists.flatten.group_by { |d| d["department_id"] }.map do |department_id, rows|
        {
          "department_id" => department_id,
          "gross_sales_cents" => rows.sum { |r| r["gross_sales_cents"].to_i },
          "return_total_cents" => rows.sum { |r| r["return_total_cents"].to_i },
          "units_sold" => rows.sum { |r| r["units_sold"].to_i }
        }
      end
    end

    def build_cash_summary(session_totals)
      {
        "sessions_with_cash" => session_totals.count { |t| t.cash["cash_enabled"] },
        "expected_cash_cents" => session_totals.sum { |t| t.cash["expected_cash_cents"].to_i },
        "counted_cash_cents" => session_totals.sum { |t| t.cash["counted_cash_cents"].to_i },
        "cash_variance_cents" => session_totals.sum { |t| t.cash["cash_variance_cents"].to_i }
      }
    end
  end
end
