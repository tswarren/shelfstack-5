# frozen_string_literal: true

module StoredValue
  # Creates a zero-balance Stored-Value account with a generated
  # organization-wide `21` EAN-13 account_number (ADR-0002; ADR-0012).
  # Creation alone creates no liability (stored-value v1 operating policy).
  # Parallel to Inventory::CreateInventoryUnit's namespace-`27` generation.
  # Permission (`stored_value.account.create`) is the caller's responsibility
  # (e.g. StoredValueAccountsController's `require_permission!`), matching how
  # PostLedgerEntry does not evaluate permission itself.
  class CreateAccount < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:account, :success?, :error)

    def initialize(organization:, actor:, account_type:, alternate_identifier: nil, store: nil)
      @organization = organization
      @actor = actor
      @account_type = account_type.to_s
      @alternate_identifier = alternate_identifier
      @store = store
    end

    def call
      raise Error, "unknown account_type: #{@account_type}" unless StoredValueAccount::ACCOUNT_TYPES.include?(@account_type)

      account = nil
      ActiveRecord::Base.transaction do
        identifier = Identifiers::Generate.call(
          namespace: "21",
          occupied: ->(candidate) { StoredValueAccount.exists?(account_number: candidate) }
        )

        account = StoredValueAccount.create!(
          organization: @organization,
          account_type: @account_type,
          account_number: identifier,
          alternate_identifier: @alternate_identifier,
          status: "active",
          current_balance_cents: 0,
          created_by_user: @actor
        )

        if @store.present?
          Administration::RecordAuditEvent.call(
            actor: @actor, organization: @organization, store: @store,
            action: "stored_value_account.created", subject: account,
            metadata: { "account_number" => account.account_number, "account_type" => account.account_type }
          )
        end
      end

      Result.new(account: account, success?: true, error: nil)
    rescue Error, ActiveRecord::RecordInvalid, Identifiers::Generate::SequenceOverflowError => e
      Result.new(account: nil, success?: false, error: e.message)
    end
  end
end
