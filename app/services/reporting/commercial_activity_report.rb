# frozen_string_literal: true

module Reporting
  class CommercialActivityReport < ApplicationService
    Row = Data.define(
      :completed_on, :gross_sales_cents, :discount_total_cents, :return_total_cents,
      :net_sales_cents, :units_sold, :units_returned, :cost_extended_cents,
      :missing_cost_line_count, :post_void_count
    )

    def initialize(store:, from_date:, to_date:)
      @store = store
      @from_date = from_date
      @to_date = to_date
    end

    def call
      txns = PosTransaction
        .where(store_id: @store.id, status: "completed")
        .where(completed_at: @from_date.beginning_of_day..@to_date.end_of_day)
        .includes(:pos_line_items)

      zone = ActiveSupport::TimeZone[@store.timezone] || Time.zone
      by_date = txns.group_by { |t| t.completed_at.in_time_zone(zone).to_date }
      by_date.keys.sort.map do |date|
        day_txns = by_date[date]
        lines = day_txns.flat_map { |t| t.pos_line_items.select { |l| l.status == "completed" && l.removed_at.nil? } }
        sales = lines.select { |l| l.direction == "sale" && l.line_kind != "stored_value" }
        returns = lines.select { |l| l.direction == "return" }
        Row.new(
          completed_on: date,
          gross_sales_cents: sales.sum { |l| l.extended_price_cents.to_i },
          discount_total_cents: day_txns.sum { |t| t.discount_total_cents.to_i },
          return_total_cents: returns.sum { |l| l.extended_price_cents.to_i },
          net_sales_cents: sales.sum { |l| l.extended_price_cents.to_i } -
            day_txns.sum { |t| t.discount_total_cents.to_i } -
            returns.sum { |l| l.extended_price_cents.to_i },
          units_sold: sales.sum { |l| l.quantity.to_i },
          units_returned: returns.sum { |l| l.quantity.to_i },
          cost_extended_cents: sales.sum { |l| l.cost_extended_cents.to_i },
          missing_cost_line_count: sales.count { |l| l.cost_extended_cents.nil? },
          post_void_count: day_txns.count { |t| t.reverses_pos_transaction_id.present? }
        )
      end
    end
  end
end
