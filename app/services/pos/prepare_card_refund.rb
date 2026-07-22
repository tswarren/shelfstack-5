# frozen_string_literal: true

module Pos
  # Persists a durable card-refund preparation before the cashier uses the
  # external terminal. While prepared, the transaction is commercially locked.
  #
  # When `replaces_pos_tender` is set, this prepares a replacement for a
  # reconciliation tender: capacity excludes that tender so a same-amount
  # replacement can be authorized before the old tender is voided.
  class PrepareCardRefund < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:ready?, :preparation, :error, :warnings)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      original_pos_tender: nil,
      exception_approver: nil,
      exception_approver_pin: nil,
      replaces_pos_tender: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @original_pos_tender = original_pos_tender
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
      @replaces_pos_tender = replaces_pos_tender
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_refund_enabled!(@tender_type)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        if transaction.card_refund_preparation_outstanding?
          raise Error, "a card refund preparation is already outstanding; record or abandon it first"
        end

        replacing = nil
        excluding_ids = []
        if @replaces_pos_tender.present?
          replacing = CardRefundSupport.assert_replaceable_recon_tender!(
            transaction, PosTender.lock.find(@replaces_pos_tender.id)
          )
          raise Error, "replacement amount must match the tender being replaced" unless @amount_cents == replacing.amount_cents
          if PosCardRefundPreparation.active_replacements_for(replacing).exists?
            raise Error, "a replacement preparation already exists for this tender"
          end
          excluding_ids = [ replacing.id ]
        end

        recalculation = FinalizeReturnFinancials.call(pos_transaction: transaction).recalculation
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        refund_due = CardRefundSupport.refund_due_cents(
          transaction, recalculation.net_total_cents, excluding_tender_ids: excluding_ids
        )
        raise Error, "no refund balance due" if refund_due.zero?
        raise Error, "refund exceeds balance due (#{refund_due})" if @amount_cents > refund_due

        original = CardRefundSupport.validate_original!(
          transaction: transaction,
          original_pos_tender: @original_pos_tender.presence || replacing&.original_pos_tender,
          amount_cents: @amount_cents,
          excluding_refund_tender: replacing
        )
        CardRefundSupport.assert_no_post_voided_linked_originals!(transaction)

        approval = RefundAllocationPolicy.call(
          pos_transaction: transaction,
          actor: @actor,
          destination: :card,
          amount_cents: @amount_cents,
          original_pos_tender: original,
          exception_approver: @exception_approver,
          exception_approver_pin: @exception_approver_pin,
          excluding_tender_ids: excluding_ids
        )

        snapshot = RefundPlanSnapshot.build(
          pos_transaction: transaction,
          tender_type: @tender_type,
          amount_cents: @amount_cents,
          actor: @actor,
          intended_original_pos_tender: original,
          pos_approval: approval,
          net_total_cents: recalculation.net_total_cents,
          refund_due_cents: refund_due
        )

        preparation = PosCardRefundPreparation.create!(
          pos_transaction: transaction,
          tender_type: @tender_type,
          intended_original_pos_tender: original,
          replaces_pos_tender: replacing,
          pos_approval: approval,
          prepared_by_user: @actor,
          amount_cents: @amount_cents,
          plan_snapshot: snapshot,
          plan_fingerprint: RefundPlanSnapshot.fingerprint(snapshot),
          fingerprint_version: RefundPlanSnapshot::VERSION,
          status: "prepared",
          expires_at: Time.current + PosCardRefundPreparation::TTL
        )

        Result.new(ready?: true, preparation: preparation, error: nil, warnings: recalculation.warnings)
      end
    rescue Error, CardRefundSupport::Error, RefundAllocationPolicy::Error, TenderGuards::Error,
           ActiveRecord::RecordInvalid => e
      Result.new(ready?: false, preparation: nil, error: e.message, warnings: [])
    end
  end
end
