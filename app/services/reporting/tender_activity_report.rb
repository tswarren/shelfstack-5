# frozen_string_literal: true

module Reporting
  class TenderActivityReport < ApplicationService
    Row = Data.define(:tender_category, :received_cents, :refunded_cents, :net_cents)

    def initialize(store:, from_date:, to_date:)
      @store = store
      @from_date = from_date
      @to_date = to_date
    end

    def call
      tenders = PosTender
        .joins(:tender_type, pos_transaction: { completed_pos_session: :business_day })
        .where(store_id: @store.id, status: "completed", removed_at: nil)
        .where(pos_transactions: { status: "completed" })
        .where(business_days: { reporting_date: @from_date..@to_date })
        .includes(:tender_type)

      tenders.group_by { |t| t.tender_type.tender_category }.map do |category, rows|
        received = rows.select { |t| t.direction == "received" }.sum(&:amount_cents)
        refunded = rows.select { |t| t.direction == "refunded" }.sum(&:amount_cents)
        Row.new(
          tender_category: category,
          received_cents: received,
          refunded_cents: refunded,
          net_cents: received - refunded
        )
      end.sort_by(&:tender_category)
    end
  end
end
