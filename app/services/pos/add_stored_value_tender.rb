# frozen_string_literal: true

module Pos
  # Redeem stored value as a received tender (not a discount).
  class AddStoredValueTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings)

    def initialize(pos_transaction:, tender_type:, account:, amount_cents:, actor:)
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @account = account
      @amount_cents = amount_cents.to_i
      @actor = actor
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be stored_value" unless @tender_type.tender_category == "stored_value"
      raise Error, "amount must be positive" unless @amount_cents.positive?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_payment_enabled!(@tender_type)

      unless Authorization::EvaluatePermission.call(
        user: @actor, store: @pos_transaction.store, permission_key: "stored_value.tender.redeem"
      ) == :allow
        raise Error, "missing permission stored_value.tender.redeem"
      end

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        TenderGuards.assert_no_outstanding_card_refund_preparation!(transaction)
        account = StoredValueAccount.lock.find(@account.id)
        raise Error, "account organization mismatch" unless account.organization_id == transaction.store.organization_id
        raise Error, "account is suspended" if account.suspended?
        raise Error, "insufficient stored-value balance" if @amount_cents > account.current_balance_cents

        recalculation = RecalculateTransaction.call(pos_transaction: transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        balance_due = TenderGuards.remaining_received_balance_cents(transaction, recalculation.net_total_cents)
        raise Error, "no balance due" if balance_due.zero?
        raise Error, "amount exceeds remaining balance (#{balance_due})" if @amount_cents > balance_due

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "received", status: "pending", amount_cents: @amount_cents,
          stored_value_account: account, created_by_user: @actor
        )

        Result.new(pos_tender: tender, success?: true, error: nil, warnings: recalculation.warnings)
      end
    rescue Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [])
    end
  end
end
