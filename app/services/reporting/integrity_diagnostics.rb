# frozen_string_literal: true

module Reporting
  class IntegrityDiagnostics < ApplicationService
    Finding = Data.define(:code, :severity, :count, :sample_ids)

    def initialize(store:)
      @store = store
    end

    def call
      [
        stock_ledger_mismatches,
        missing_session_z,
        missing_line_cost
      ].compact
    end

    private

    def stock_ledger_mismatches
      mismatches = []
      StockBalance.where(store_id: @store.id).find_each do |balance|
        ledger_qty = InventoryLedgerEntry.where(
          store_id: @store.id, product_variant_id: balance.product_variant_id
        ).sum(:quantity_delta)
        mismatches << balance.id if ledger_qty != balance.on_hand
      end
      return if mismatches.empty?

      Finding.new(
        code: "stock_ledger_mismatch",
        severity: "warning",
        count: mismatches.size,
        sample_ids: mismatches.first(10)
      )
    end

    def missing_session_z
      ids = PosSession.where(store_id: @store.id, status: "closed")
        .left_outer_joins(:pos_session_z_report)
        .where(pos_session_z_reports: { id: nil })
        .limit(10)
        .pluck(:id)
      return if ids.empty?

      Finding.new(code: "missing_session_z", severity: "warning", count: ids.size, sample_ids: ids)
    end

    def missing_line_cost
      ids = PosLineItem
        .joins(:pos_transaction)
        .where(pos_transactions: { store_id: @store.id, status: "completed" })
        .where(status: "completed", removed_at: nil, line_kind: %w[product open_ring], direction: "sale")
        .where(cost_extended_cents: nil)
        .limit(10)
        .pluck(:id)
      return if ids.empty?

      Finding.new(code: "missing_cost", severity: "info", count: ids.size, sample_ids: ids)
    end

  end
end

