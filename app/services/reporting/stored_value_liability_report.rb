# frozen_string_literal: true

module Reporting
  # Store-scoped activity / ledger effect — not organization-wide outstanding liability.
  class StoredValueLiabilityReport < ApplicationService
    Result = Data.define(:by_type, :net_ledger_effect_cents, :cache_ledger_mismatches)

    def initialize(organization:, store:)
      @organization = organization
      @store = store
    end

    def call
      entries = StoredValueEntry.where(store_id: @store.id)
        .joins(:stored_value_account)
        .where(stored_value_accounts: { organization_id: @organization.id })
        .includes(:stored_value_account)

      by_type = entries.group_by { |e| e.stored_value_account.account_type }.map do |type, rows|
        {
          "account_type" => type,
          "entry_count" => rows.size,
          "account_count" => rows.map(&:stored_value_account_id).uniq.size,
          "issued_cents" => sum_ops(rows, %w[issued]),
          "reloaded_cents" => sum_ops(rows, %w[reloaded]),
          "redeemed_cents" => sum_ops(rows, %w[redeemed]),
          "refunded_cents" => sum_ops(rows, %w[refunded]),
          "adjusted_cents" => sum_ops(rows, %w[manual_adjustment]),
          "reversed_cents" => sum_ops(rows, %w[reversal]),
          "net_ledger_effect_cents" => rows.sum(&:amount_cents)
        }
      end.sort_by { |row| row["account_type"].to_s }

      Result.new(
        by_type: by_type,
        net_ledger_effect_cents: entries.sum(&:amount_cents),
        cache_ledger_mismatches: [] # org-wide cache integrity is deferred
      )
    end

    private

    def sum_ops(rows, operations)
      rows.select { |r| operations.include?(r.entry_type.to_s) }.sum(&:amount_cents)
    end
  end
end
