# frozen_string_literal: true

module StoredValue
  # Exclusive owner of the Stored-Value balance posting contract (ADR-0012;
  # stored-value v1 operating policy "Balance posting contract"): lock
  # account → check status/eligibility → check posting key → validate
  # sufficient balance for a debit → create the immutable Entry → update the
  # cached balance → audit → commit.
  class PostEntry < ApplicationService
    Error = Class.new(StandardError)
    AccountNotActiveError = Class.new(Error)
    InsufficientBalanceError = Class.new(Error)
    IdempotencyConflictError = Class.new(Error)
    ReversalError = Class.new(Error)
    LifecycleError = Class.new(Error)

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

      ActiveRecord::Base.transaction do
        account = StoredValueAccount.lock.find(@account.id)

        existing = StoredValueEntry.find_by(posting_key: @posting_key)
        return replay_or_conflict!(existing) if existing

        unless @allow_suspended || account.active?
          raise AccountNotActiveError, "account #{account.account_number} is not active"
        end

        validate_lifecycle!(account)
        locked_original = validate_and_lock_reversal!(account)

        balance_before = account.current_balance_cents
        resulting_balance = balance_before + @amount_cents
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
          reverses_entry: locked_original || @reverses_entry,
          stored_value_adjustment_reason: @adjustment_reason,
          description: @description,
          created_by_user: @actor,
          pos_approval: @pos_approval,
          posting_key: @posting_key,
          created_at: @created_at
        )

        account.update!(current_balance_cents: resulting_balance)
        record_audit!(entry, account, balance_before, resulting_balance)

        Result.new(entry: entry, account: account, replayed: false)
      end
    rescue ArgumentError => e
      raise Error, e.message
    rescue ActiveRecord::RecordNotUnique => e
      existing = StoredValueEntry.find_by(posting_key: @posting_key)
      return replay_or_conflict!(existing) if existing

      if @entry_type == "issued"
        raise LifecycleError, "account already has an issued entry"
      elsif @reverses_entry.present?
        raise ReversalError, "entry #{@reverses_entry.id} is already reversed"
      else
        raise Error, e.message
      end
    end

    private

    def validate_preconditions!
      raise Error, "posting_key is required" if @posting_key.blank?
      raise Error, "account is required" if @account.blank?
      raise Error, "store is required" if @store.blank?
      raise Error, "unsupported entry_type: #{@entry_type}" unless StoredValueEntry::ENTRY_TYPES.include?(@entry_type)
      raise Error, "amount_cents must be nonzero" if @amount_cents.zero?

      if @entry_type == "reversal" && @reverses_entry.blank?
        raise ReversalError, "reversal requires reverses_entry"
      end
      if @reverses_entry.present? && @entry_type != "reversal"
        raise ReversalError, "reverses_entry requires entry_type reversal"
      end
    end

    def validate_lifecycle!(account)
      case @entry_type
      when "issued"
        unless account.account_type == "gift_card"
          raise LifecycleError, "issued entries are only allowed on gift_card accounts"
        end
        if StoredValueEntry.exists?(stored_value_account_id: account.id, entry_type: "issued")
          raise LifecycleError, "account already has an issued entry"
        end
        raise LifecycleError, "issued amount must be positive" unless @amount_cents.positive?
      when "reloaded"
        unless account.account_type == "gift_card"
          raise LifecycleError, "reloaded entries are only allowed on gift_card accounts"
        end
        unless StoredValueEntry.exists?(stored_value_account_id: account.id, entry_type: "issued")
          raise LifecycleError, "reload requires a prior issued entry"
        end
        raise LifecycleError, "reloaded amount must be positive" unless @amount_cents.positive?
      end
    end

    def validate_and_lock_reversal!(account)
      return nil if @reverses_entry.blank?

      original = StoredValueEntry.lock.find(@reverses_entry.id)
      unless original.stored_value_account_id == account.id
        raise ReversalError, "reversal account must match original entry account"
      end
      unless @amount_cents == -original.amount_cents
        raise ReversalError, "reversal amount must be the exact inverse of the original entry"
      end
      if StoredValueEntry.exists?(reverses_entry_id: original.id)
        raise ReversalError, "entry #{original.id} is already reversed"
      end

      original
    end

    def record_audit!(entry, account, balance_before, balance_after)
      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: account.organization,
        store: @store,
        action: "stored_value.entry.posted",
        subject: entry,
        metadata: {
          "stored_value_account_id" => account.id,
          "account_number" => account.account_number,
          "entry_type" => entry.entry_type,
          "amount_cents" => entry.amount_cents,
          "balance_before_cents" => balance_before,
          "balance_after_cents" => balance_after,
          "pos_transaction_id" => entry.pos_transaction_id,
          "pos_line_item_id" => entry.pos_line_item_id,
          "pos_tender_id" => entry.pos_tender_id,
          "reverses_entry_id" => entry.reverses_entry_id,
          "pos_approval_id" => entry.pos_approval_id,
          "posting_key" => entry.posting_key
        }
      )
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
