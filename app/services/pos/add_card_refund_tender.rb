# frozen_string_literal: true

module Pos
  # Standalone-card refund tender for linked returns.
  #
  # External terminal authorization is confirmed by the cashier before this call
  # (MVP limitation parallel to AddCardTender / ADR-0009). Because the money has
  # already moved externally, this service always retains a durable authorized
  # tender when an authorization code is supplied. If internal plan validation
  # fails after that point, the tender is stored with `requires_reconciliation`
  # rather than discarded — completion is blocked until resolved or voided.
  #
  # Call PrepareCardRefund before sending the cashier to the terminal.
  class AddCardRefundTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings, :requires_reconciliation)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      authorization_code:,
      actor:,
      terminal_reference: nil,
      original_pos_tender: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @actor = actor
      @original_pos_tender = original_pos_tender
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?
      raise Error, "authorization code is required" if @authorization_code.blank?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_refund_enabled!(@tender_type)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        RefundLockOrder.lock_linked_originals!(transaction)

        reasons = []
        warnings = []
        original = nil
        approval = nil

        unless transaction.open?
          reasons << "transaction is not open (status=#{transaction.status})"
        end

        begin
          recalculation = RecalculateTransaction.call(pos_transaction: transaction)
          warnings.concat(Array(recalculation.warnings))
          if recalculation.blockers.present?
            reasons << "calculation blockers: #{recalculation.blockers.join(', ')}"
          else
            refund_due = CardRefundSupport.refund_due_cents(transaction, recalculation.net_total_cents)
            reasons << "no refund balance due" if refund_due.zero?
            if refund_due.positive? && @amount_cents > refund_due
              reasons << "refund exceeds balance due (#{refund_due})"
            end
          end

          CardRefundSupport.assert_no_post_voided_linked_originals!(transaction)
          original = CardRefundSupport.validate_original!(
            transaction: transaction,
            original_pos_tender: @original_pos_tender,
            amount_cents: @amount_cents
          )

          approval = RefundAllocationPolicy.call(
            pos_transaction: transaction,
            actor: @actor,
            destination: :card,
            amount_cents: @amount_cents,
            original_pos_tender: original,
            exception_approver: @exception_approver,
            exception_approver_pin: @exception_approver_pin
          )
        rescue CardRefundSupport::Error, RefundAllocationPolicy::Error, TenderGuards::Error => e
          reasons << e.message
          original = nil if e.is_a?(CardRefundSupport::Error)
          approval = nil
        end

        requires_reconciliation = reasons.any?
        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "refunded", status: "authorized", amount_cents: @amount_cents,
          authorization_code: @authorization_code, terminal_reference: @terminal_reference,
          authorized_at: Time.current, original_pos_tender: original,
          requires_reconciliation: requires_reconciliation,
          created_by_user: @actor,
          pos_approval: approval
        )

        if requires_reconciliation
          Administration::RecordAuditEvent.call(
            actor: @actor, organization: transaction.store.organization, store: transaction.store,
            action: "pos_tender.card_refund_requires_reconciliation", subject: tender,
            metadata: {
              "authorization_code" => @authorization_code,
              "reasons" => reasons,
              "amount_cents" => @amount_cents
            }
          )
        end

        Result.new(
          pos_tender: tender,
          success?: true,
          error: nil,
          warnings: (warnings + reasons).uniq,
          requires_reconciliation: requires_reconciliation
        )
      end
    rescue Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(
        pos_tender: nil, success?: false, error: e.message, warnings: [],
        requires_reconciliation: false
      )
    end
  end
end
