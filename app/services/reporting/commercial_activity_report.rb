# frozen_string_literal: true

module Reporting
  class CommercialActivityReport < ApplicationService
    Row = Data.define(
      :completed_on, :gross_sales_cents, :discount_total_cents, :return_total_cents,
      :post_void_commercial_effect_cents, :net_sales_cents, :units_sold, :units_returned,
      :sale_cogs_cents, :customer_return_cogs_reversal_cents, :post_void_cogs_effect_cents,
      :net_cogs_cents, :cost_extended_cents, :missing_cost_line_count, :post_void_count
    )

    def initialize(store:, from_date:, to_date:)
      @store = store
      @from_date = from_date
      @to_date = to_date
    end

    def call
      txns = PosTransaction
        .joins(completed_pos_session: :business_day)
        .where(store_id: @store.id, status: "completed")
        .where(business_days: { reporting_date: @from_date..@to_date })
        .includes(:pos_line_items, completed_pos_session: :business_day)

      by_date = txns.group_by { |t| t.completed_pos_session.business_day.reporting_date }
      by_date.keys.sort.map do |date|
        day_txns = by_date[date]
        void_ids = day_txns.select { |t| t.reverses_pos_transaction_id.present? }.map(&:id).to_set
        lines = day_txns.flat_map { |t| t.pos_line_items.select { |l| l.status == "completed" && l.removed_at.nil? } }
        ordinary_lines = lines.reject { |l| void_ids.include?(l.pos_transaction_id) }
        void_lines = lines.select { |l| void_ids.include?(l.pos_transaction_id) }
        ordinary_txns = day_txns.reject { |t| void_ids.include?(t.id) }
        void_txns = day_txns.select { |t| void_ids.include?(t.id) }

        sales = ordinary_lines.select { |l| l.direction == "sale" && l.line_kind != "stored_value" }
        returns = ordinary_lines.select { |l| l.direction == "return" && l.line_kind != "stored_value" }
        gross = sales.sum { |l| l.extended_price_cents.to_i }
        discounts = ordinary_txns.sum { |t| t.discount_total_cents.to_i }
        return_total = returns.sum { |l| l.extended_price_cents.to_i }
        post_void_effect = void_txns.sum { |t|
          txn_lines = void_lines.select { |l| l.pos_transaction_id == t.id && l.line_kind != "stored_value" }
          sale_ext = txn_lines.select { |l| l.direction == "sale" }.sum { |l| l.extended_price_cents.to_i }
          return_ext = txn_lines.select { |l| l.direction == "return" }.sum { |l| l.extended_price_cents.to_i }
          sale_ext - return_ext - t.discount_total_cents.to_i
        }
        sale_cogs = sales.sum { |l| l.cost_extended_cents.to_i }
        return_cogs = returns.sum { |l| l.cost_extended_cents.to_i }
        void_cogs = void_lines.select { |l| l.line_kind != "stored_value" }.sum { |l|
          l.direction == "sale" ? l.cost_extended_cents.to_i : -l.cost_extended_cents.to_i
        }
        net_cogs = sale_cogs - return_cogs + void_cogs
        net_sales = gross - discounts - return_total + post_void_effect

        Row.new(
          completed_on: date,
          gross_sales_cents: gross,
          discount_total_cents: discounts,
          return_total_cents: return_total,
          post_void_commercial_effect_cents: post_void_effect,
          net_sales_cents: net_sales,
          units_sold: sales.sum { |l| l.quantity.to_i },
          units_returned: returns.sum { |l| l.quantity.to_i },
          sale_cogs_cents: sale_cogs,
          customer_return_cogs_reversal_cents: return_cogs,
          post_void_cogs_effect_cents: void_cogs,
          net_cogs_cents: net_cogs,
          cost_extended_cents: net_cogs,
          missing_cost_line_count: ordinary_lines.count { |l| l.line_kind != "stored_value" && l.cost_extended_cents.nil? },
          post_void_count: void_txns.size
        )
      end
    end
  end
end
