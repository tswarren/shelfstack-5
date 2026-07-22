# frozen_string_literal: true

module Pos
  # Refund to stored value: restore an original SV tender, or issue store credit.
  class AddStoredValueRefundTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :account, :success?, :error, :warnings)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      account: nil,
      original_pos_tender: nil,
      create_store_credit: false,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @account = account
      @original_pos_tender = original_pos_tender
      @create_store_credit = create_store_credit
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be stored_value" unless @tender_type.tender_category == "stored_value"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_refund_enabled!(@tender_type)

      unless Authorization::EvaluatePermission.call(
        user: @actor, store: @pos_transaction.store, permission_key: "stored_value.tender.refund"
      ) == :allow
        raise Error, "missing permission stored_value.tender.refund"
      end

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        TenderGuards.assert_no_outstanding_card_refund_preparation!(transaction)

        recalculation = RecalculateTransaction.call(pos_transaction: transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        refund_due = [ -recalculation.net_total_cents - already_refunded_cents(transaction), 0 ].max
        raise Error, "no refund balance due" if refund_due.zero?
        raise Error, "refund exceeds balance due (#{refund_due})" if @amount_cents > refund_due

        original = lock_and_validate_original!(transaction)
        destination = original.present? ? :original_stored_value : :new_stored_value
        approval = RefundAllocationPolicy.call(
          pos_transaction: transaction,
          actor: @actor,
          destination: destination,
          amount_cents: @amount_cents,
          original_pos_tender: original,
          exception_approver: @exception_approver,
          exception_approver_pin: @exception_approver_pin
        )
        account = resolve_account!(transaction, original)

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "refunded", status: "pending", amount_cents: @amount_cents,
          stored_value_account: account, original_pos_tender: original,
          created_by_user: @actor,
          pos_approval: approval
        )

        Result.new(
          pos_tender: tender, account: account, success?: true, error: nil,
          warnings: recalculation.warnings
        )
      end
    rescue Error, RefundAllocationPolicy::Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, account: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def resolve_account!(transaction, original)
      if original.present?
        raise Error, "original tender has no stored-value account" if original.stored_value_account_id.blank?

        return StoredValueAccount.lock.find(original.stored_value_account_id)
      end

      if @account.present?
        account = StoredValueAccount.lock.find(@account.id)
        raise Error, "account organization mismatch" unless account.organization_id == transaction.store.organization_id
        unless account.account_type == "store_credit"
          raise Error, "non-original stored-value refund must credit a store_credit account"
        end
        return account
      end

      if @create_store_credit
        created = StoredValue::CreateAccount.call(
          organization: transaction.store.organization,
          account_type: "store_credit",
          actor: @actor,
          store: transaction.store
        )
        raise Error, created.error unless created.success?

        return StoredValueAccount.lock.find(created.account.id)
      end

      raise Error, "account, original tender, or create_store_credit is required"
    end

    def lock_and_validate_original!(transaction)
      return nil if @original_pos_tender.blank?

      original_txn = PosTransaction.lock.find(@original_pos_tender.pos_transaction_id)
      raise Error, "original tender's transaction has been post-voided" if original_txn.post_voided?
      raise Error, "original tender is not linked to this return transaction" unless linked_original_transaction?(transaction, original_txn)

      original = PosTender.lock.find(@original_pos_tender.id)
      raise Error, "original tender is not completed" unless original.completed?
      raise Error, "original tender is not a received tender" unless original.direction == "received"
      raise Error, "original tender has no stored-value account" if original.stored_value_account_id.blank?
      raise Error, "original tender has been post-voided" if original.post_voided?
      raise Error, "original tender store mismatch" unless original.store_id == transaction.store_id
      raise Error, "original tender must be stored_value" unless original.tender_type.tender_category == "stored_value"

      remaining = original.remaining_refundable_cents
      raise Error, "refund exceeds remaining refundable on original tender (#{remaining})" if @amount_cents > remaining

      original
    end

    def linked_original_transaction?(transaction, original_txn)
      transaction.pos_line_items.pending.returns.any? { |line|
        line.original_pos_line_item&.pos_transaction_id == original_txn.id
      }
    end

    def already_refunded_cents(transaction)
      transaction.pos_tenders.unresolved.where(direction: "refunded").sum(:amount_cents)
    end
  end
end
