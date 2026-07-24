# frozen_string_literal: true

module Reporting
  BusinessDayTotals = Data.define(
    :report_definition_version,
    :business_day_id,
    :store_id,
    :business_date,
    :source_cutoff_at,
    :mode,
    :identity,
    :commercial,
    :tax,
    :stored_value,
    :settlement,
    :tenders,
    :cash_summary,
    :departments,
    :activity_counts,
    :session_breakdown,
    :exceptions
  ) do
    def to_payload
      {
        "report_definition_version" => report_definition_version,
        "business_day_id" => business_day_id,
        "store_id" => store_id,
        "business_date" => business_date.iso8601,
        "source_cutoff_at" => source_cutoff_at.iso8601(6),
        "mode" => mode,
        "identity" => identity,
        "commercial" => commercial,
        "tax" => tax,
        "stored_value" => stored_value,
        "settlement" => settlement,
        "tenders" => tenders,
        "cash_summary" => cash_summary,
        "departments" => departments,
        "activity_counts" => activity_counts,
        "session_breakdown" => session_breakdown,
        "exceptions" => exceptions
      }
    end
  end
end
