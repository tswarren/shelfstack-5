# frozen_string_literal: true

module StoredValue
  # Manual balance adjustment with mandatory independent approval.
  # Lock account → recheck posting_key → approve → post, all in one transaction.
  class AdjustBalance < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:entry, :account, :pos_approval, :success?, :error, :replayed)

    def initialize(
      account:,
      store:,
      amount_cents:,
      adjustment_reason:,
      actor:,
      description: nil,
      approver:,
      approver_pin:,
      posting_key:
    )
      @account = account
      @store = store
      @amount_cents = amount_cents.to_i
      @adjustment_reason = adjustment_reason
      @actor = actor
      @description = description
      @approver = approver
      @approver_pin = approver_pin
      @posting_key = posting_key.to_s
    end

    def call
      raise Error, "posting_key is required" if @posting_key.blank?
      raise Error, "amount must be non-zero" if @amount_cents.zero?
      raise Error, "adjustment reason is required" if @adjustment_reason.blank?
      raise Error, "adjustment reason is inactive" unless @adjustment_reason.active?
      if @adjustment_reason.requires_note? && @description.blank?
        raise Error, "description is required for this reason"
      end

      ActiveRecord::Base.transaction do
        StoredValueAccount.lock.find(@account.id)

        existing = StoredValueEntry.find_by(posting_key: @posting_key)
        return replay_existing!(existing) if existing

        auth = Pos::AuthorizeAction.call(
          store: @store,
          requester: @actor,
          permission_key: "stored_value.adjustment.create",
          action_type: "stored_value_adjustment",
          reason: @description.presence || @adjustment_reason.name,
          approval_mode: :always,
          approver: @approver,
          approver_pin: @approver_pin,
          approver_permission_key: "stored_value.adjustment.approve",
          self_approver_permission_key: "stored_value.adjustment.approve_self",
          requested_value: @amount_cents
        )
        raise Error, auth.error || "adjustment approval required" unless auth.allowed? && auth.pos_approval

        posted = PostEntry.call(
          account: @account,
          store: @store,
          entry_type: "manual_adjustment",
          amount_cents: @amount_cents,
          posting_key: @posting_key,
          actor: @actor,
          adjustment_reason: @adjustment_reason,
          description: @description,
          pos_approval: auth.pos_approval,
          allow_suspended: true
        )

        Result.new(
          entry: posted.entry, account: posted.account, pos_approval: auth.pos_approval,
          success?: true, error: nil, replayed: posted.replayed
        )
      end
    rescue Error, PostEntry::Error, ActiveRecord::RecordInvalid => e
      Result.new(entry: nil, account: nil, pos_approval: nil, success?: false, error: e.message, replayed: false)
    end

    private

    def replay_existing!(existing)
      unless existing.entry_type == "manual_adjustment" &&
             existing.stored_value_account_id == @account.id &&
             existing.amount_cents == @amount_cents &&
             existing.stored_value_adjustment_reason_id == @adjustment_reason.id
        raise Error, "posting_key #{@posting_key} already used with different intent"
      end

      Result.new(
        entry: existing,
        account: @account.reload,
        pos_approval: existing.pos_approval,
        success?: true,
        error: nil,
        replayed: true
      )
    end
  end
end
