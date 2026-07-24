# frozen_string_literal: true

module Reporting
  class TaxActivityReport < ApplicationService
    Row = Data.define(:receipt_code, :name, :amount_cents)

    def initialize(store:, from_date:, to_date:)
      @store = store
      @from_date = from_date
      @to_date = to_date
    end

    def call
      taxes = PosLineItemTax
        .joins(pos_line_item: { pos_transaction: { completed_pos_session: :business_day } })
        .where(pos_transactions: { store_id: @store.id, status: "completed" })
        .where(business_days: { reporting_date: @from_date..@to_date })
        .where(pos_line_items: { status: "completed", removed_at: nil })
        .includes(:store_tax_rate, :pos_line_item)

      taxes.group_by(&:store_tax_rate_id).map do |_rate_id, rows|
        rate = rows.first.store_tax_rate
        code = rows.first.receipt_code_snapshot.presence || rate&.receipt_code.presence || "tax"
        name = rate&.name.presence || code
        amount = rows.sum do |tax|
          line = tax.pos_line_item
          cents = tax.amount_cents.to_i
          line&.direction == "return" ? -cents : cents
        end
        Row.new(receipt_code: code, name: name, amount_cents: amount)
      end.sort_by(&:name)
    end
  end
end
