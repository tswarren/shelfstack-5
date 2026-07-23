# frozen_string_literal: true

module Reporting
  class StoredValueLiabilityReport < ApplicationService
    Result = Data.define(:by_type, :cache_ledger_mismatches)

    def initialize(organization:, store: nil)
      @organization = organization
      @store = store
    end

    def call
      accounts = StoredValueAccount.where(organization_id: @organization.id)
      by_type = accounts.group_by(&:account_type).map do |type, rows|
        {
          "account_type" => type,
          "account_count" => rows.size,
          "cached_balance_cents" => rows.sum(&:current_balance_cents),
          "ledger_balance_cents" => rows.sum { |a| ledger_balance(a) }
        }
      end

      mismatches = accounts.filter_map do |account|
        ledger = ledger_balance(account)
        next if ledger == account.current_balance_cents

        {
          "account_id" => account.id,
          "account_number" => account.account_number,
          "cached_balance_cents" => account.current_balance_cents,
          "ledger_balance_cents" => ledger
        }
      end

      Result.new(by_type: by_type, cache_ledger_mismatches: mismatches)
    end

    private

    def ledger_balance(account)
      scope = account.stored_value_entries
      scope = scope.where(store_id: @store.id) if @store
      scope.sum(:amount_cents)
    end
  end
end
