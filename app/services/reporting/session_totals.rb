# frozen_string_literal: true

module Reporting
  SessionTotals = Data.define(
    :report_definition_version,
    :pos_session_id,
    :store_id,
    :business_day_id,
    :business_date,
    :source_cutoff_at,
    :commercial,
    :tax,
    :stored_value,
    :settlement,
    :tenders,
    :cash,
    :departments,
    :activity_counts,
    :exceptions
  ) do
    def to_payload
      {
        "report_definition_version" => report_definition_version,
        "pos_session_id" => pos_session_id,
        "store_id" => store_id,
        "business_day_id" => business_day_id,
        "business_date" => business_date.iso8601,
        "source_cutoff_at" => source_cutoff_at.iso8601(6),
        "commercial" => commercial,
        "tax" => tax,
        "stored_value" => stored_value,
        "settlement" => settlement,
        "tenders" => tenders,
        "cash" => cash,
        "departments" => departments,
        "activity_counts" => activity_counts,
        "exceptions" => exceptions
      }
    end
  end
end
