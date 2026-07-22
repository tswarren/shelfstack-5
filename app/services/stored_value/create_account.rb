# frozen_string_literal: true

module StoredValue
  # Creates a zero-balance Stored-Value account with a generated
  # organization-wide `21` EAN-13 account_number (ADR-0002; ADR-0012).
  # Creation alone creates no liability (stored-value v1 operating policy).
  # Parallel to Inventory::CreateInventoryUnit's namespace-`27` generation.
  # Permission (`stored_value.account.create`) is the caller's responsibility
  # (e.g. StoredValueAccountsController's `require_permission!`), matching how
  # PostLedgerEntry does not evaluate permission itself.
  #
  # Canonical account numbers and organization-scoped alternate identifiers share
  # one occupation space so resolver lookups cannot become permanently ambiguous.
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

      normalized_alternate = StoredValueAccount.normalize_alternate_identifier(@alternate_identifier)

      account = nil
      ActiveRecord::Base.transaction do
        if normalized_alternate.present? &&
           StoredValueAccount.credential_occupied?(
             organization_id: @organization.id, value: normalized_alternate
           )
          raise Error, "alternate identifier is already used as an account number or alternate identifier"
        end

        identifier = Identifiers::Generate.call(
          namespace: "21",
          occupied: ->(candidate) {
            StoredValueAccount.credential_occupied?(
              organization_id: @organization.id, value: candidate
            )
          }
        )

        account = StoredValueAccount.create!(
          organization: @organization,
          account_type: @account_type,
          account_number: identifier,
          alternate_identifier: normalized_alternate,
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
