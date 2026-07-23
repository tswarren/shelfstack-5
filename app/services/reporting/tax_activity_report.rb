# frozen_string_literal: true

module Reporting
  class TaxActivityReport < ApplicationService
    Row = Data.define(:receipt_code, :amount_cents)

    def initialize(store:, from_date:, to_date:)
      @store = store
      @from_date = from_date
      @to_date = to_date
    end

    def call
      taxes = PosLineItemTax
        .joins(pos_line_item: :pos_transaction)
        .where(pos_transactions: {
          store_id: @store.id,
          status: "completed",
          completed_at: @from_date.beginning_of_day..@to_date.end_of_day
        })
        .where(pos_line_items: { status: "completed", removed_at: nil })

      taxes.group_by { |t| t.receipt_code_snapshot.presence || "tax" }.map do |code, rows|
        Row.new(receipt_code: code, amount_cents: rows.sum(&:amount_cents))
      end.sort_by(&:receipt_code)
    end
  end
end
