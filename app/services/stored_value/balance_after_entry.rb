# frozen_string_literal: true

module StoredValue
  # Historical balance immediately after a completed ledger entry.
  # Sums all entries for the account through the selected entry in ledger order.
  class BalanceAfterEntry < ApplicationService
    Result = Data.define(:entry, :balance_cents)

    def initialize(entry:)
      @entry = entry
    end

    def call
      balance = StoredValueEntry
        .where(stored_value_account_id: @entry.stored_value_account_id)
        .where(
          "(created_at < :created_at) OR (created_at = :created_at AND id <= :id)",
          created_at: @entry.created_at,
          id: @entry.id
        )
        .sum(:amount_cents)

      Result.new(entry: @entry, balance_cents: balance)
    end
  end
end
