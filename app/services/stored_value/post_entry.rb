# frozen_string_literal: true

module StoredValue
  # Exclusive owner of the Stored-Value balance posting contract (ADR-0012;
  # stored-value v1 operating policy "Balance posting contract"): lock
  # account → check status/eligibility → check posting key → validate
  # sufficient balance for a debit → create the immutable Entry → update the
  # cached balance → commit. Idempotent by `posting_key`, mirroring
  # Inventory::PostLedgerEntry. Does not itself evaluate permission or
  # approval — callers (Pos::AddStoredValueLine/Tender, StoredValue::AdjustBalance,
  # Pos::PostVoidTransaction) authorize before calling, the same separation
  # PostLedgerEntry uses.
  class PostEntry < ApplicationService
    Error = Class.new(StandardError)
    AccountNotActiveError = Class.new(Error)
    InsufficientBalanceError = Class.new(Error)
    IdempotencyConflictError = Class.new(Error)

    Result = Data.define(:entry, :account, :replayed)

    def initialize(
      account:,
      store:,
      entry_type:,
      amount_cents:,
      posting_key:,
      actor:,
      pos_transaction: nil,
      pos_line_item: nil,
      pos_tender: nil,
      reverses_entry: nil,
      adjustment_reason: nil,
      description: nil,
      pos_approval: nil,
      created_at: nil,
      allow_suspended: false
    )
      @account = account
      @store = store
      @entry_type = entry_type.to_s
      @amount_cents = amount_cents.to_i
      @posting_key = posting_key.to_s
      @actor = actor
      @pos_transaction = pos_transaction
      @pos_line_item = pos_line_item
      @pos_tender = pos_tender
      @reverses_entry = reverses_entry
      @adjustment_reason = adjustment_reason
      @description = description
      @pos_approval = pos_approval
      @created_at = created_at || Time.current
      @allow_suspended = allow_suspended
    end

    def call
      validate_preconditions!

      existing = StoredValueEntry.find_by(posting_key: @posting_key)
      return replay_or_conflict!(existing) if existing

      ActiveRecord::Base.transaction do
        account = StoredValueAccount.lock.find(@account.id)

        unless @allow_suspended || account.active?
          raise AccountNotActiveError, "account #{account.account_number} is not active"
        end

        resulting_balance = account.current_balance_cents + @amount_cents
        if resulting_balance.negative?
          raise InsufficientBalanceError, "insufficient balance on account #{account.account_number}"
        end

        entry = StoredValueEntry.create!(
          stored_value_account: account,
          store: @store,
          entry_type: @entry_type,
          amount_cents: @amount_cents,
          pos_transaction: @pos_transaction,
          pos_line_item: @pos_line_item,
          pos_tender: @pos_tender,
          reverses_entry: @reverses_entry,
          stored_value_adjustment_reason: @adjustment_reason,
          description: @description,
          created_by_user: @actor,
          pos_approval: @pos_approval,
          posting_key: @posting_key,
          created_at: @created_at
        )

        account.update!(current_balance_cents: resulting_balance)

        Result.new(entry: entry, account: account, replayed: false)
      end
    rescue ArgumentError => e
      raise Error, e.message
    rescue ActiveRecord::RecordNotUnique
      existing = StoredValueEntry.find_by!(posting_key: @posting_key)
      replay_or_conflict!(existing)
    end

    private

    def validate_preconditions!
      raise Error, "posting_key is required" if @posting_key.blank?
      raise Error, "account is required" if @account.blank?
      raise Error, "store is required" if @store.blank?
      raise Error, "unsupported entry_type: #{@entry_type}" unless StoredValueEntry::ENTRY_TYPES.include?(@entry_type)
      raise Error, "amount_cents must be nonzero" if @amount_cents.zero?
    end

    def replay_or_conflict!(existing)
      unless compatible_with?(existing)
        raise IdempotencyConflictError, "posting_key #{@posting_key} already used with different intent"
      end

      account = StoredValueAccount.find(existing.stored_value_account_id)
      Result.new(entry: existing, account: account, replayed: true)
    end

    def compatible_with?(existing)
      existing.stored_value_account_id == @account.id &&
        existing.store_id == @store.id &&
        existing.entry_type == @entry_type &&
        existing.amount_cents == @amount_cents &&
        existing.pos_transaction_id == @pos_transaction&.id &&
        existing.pos_line_item_id == @pos_line_item&.id &&
        existing.pos_tender_id == @pos_tender&.id &&
        existing.reverses_entry_id == @reverses_entry&.id &&
        existing.stored_value_adjustment_reason_id == @adjustment_reason&.id
    end
  end
end
