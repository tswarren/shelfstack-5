# frozen_string_literal: true

module Pos
  # Records an operator-confirmed standalone-terminal card refund directly
  # (no preparation table). New tender references are recorded; original tender
  # refs are never copied. Once references validate, any later business failure
  # that prevents attachment persists a `void_required` tender.
  #
  # `recording_idempotency_key` is a client-generated request UUID shared by the
  # authorized or void_required outcome (ADR-0016 request idempotency).
  class AddCardRefundTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings, :requires_void_confirmation?)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      recording_idempotency_key: nil,
      authorization_code: nil,
      terminal_reference: nil,
      reference_1: nil,
      reference_2: nil,
      original_pos_tender: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @recording_idempotency_key = recording_idempotency_key.to_s.strip.presence || SecureRandom.uuid
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @reference_1 = reference_1
      @reference_2 = reference_2
      @original_pos_tender = original_pos_tender
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
      @proposed_authorization_code = CardRecordingIdempotency.normalize_reference(
        reference_1.nil? ? authorization_code : reference_1
      )
      @proposed_terminal_reference = CardRecordingIdempotency.normalize_reference(
        reference_2.nil? ? terminal_reference : reference_2
      )
    end

    def call
      begin
        validate_structure!
      rescue Error => e
        return failure(e.message, requires_void_confirmation: false)
      end

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        replay = resolve_recording_idempotency!(transaction)
        return replay if replay

        refs = begin
          ValidateTenderReferences.call(
            tender_type: @tender_type,
            reference_1: @reference_1,
            reference_2: @reference_2,
            authorization_code: @authorization_code,
            terminal_reference: @terminal_reference
          )
        rescue ValidateTenderReferences::Error => e
          return failure(e.message, requires_void_confirmation: false)
        end

        attach_authorized!(transaction, refs)
      end
    rescue Error, CardRefundSupport::Error, RefundAllocationPolicy::Error,
           TenderGuards::Error, ActiveRecord::RecordInvalid => e
      retain_void_required_after_failure!(e.message)
    end

    private

    def validate_structure!
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?
    end

    def attach_authorized!(transaction, refs)
      unless transaction.open?
        return retain_void_required!(transaction, refs, "transaction is not open")
      end

      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_refund_enabled!(@tender_type)
      CardRefundSupport.assert_no_post_voided_linked_originals!(transaction)

      recalculation = FinalizeReturnFinancials.call(pos_transaction: transaction).recalculation
      TenderGuards.assert_no_calculation_blockers!(recalculation)

      refund_due = CardRefundSupport.refund_due_cents(transaction, recalculation.net_total_cents)
      if refund_due.zero? || @amount_cents > refund_due
        raise Error,
              "refund amount is not attachable (remaining #{refund_due}); " \
              "confirm external void and record as voided"
      end

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

      tender = PosTender.create!(
        pos_transaction: transaction,
        store: transaction.store,
        tender_type: @tender_type,
        direction: "refunded",
        status: "authorized",
        amount_cents: @amount_cents,
        authorization_code: refs.authorization_code,
        terminal_reference: refs.terminal_reference,
        authorized_at: Time.current,
        original_pos_tender: original,
        created_by_user: @actor,
        pos_approval: approval,
        recording_idempotency_key: @recording_idempotency_key
      )

      Result.new(
        pos_tender: tender, success?: true, error: nil,
        warnings: Array(recalculation.warnings), requires_void_confirmation?: false
      )
    end

    def resolve_recording_idempotency!(transaction)
      outcome = CardRecordingIdempotency.resolve!(
        recording_idempotency_key: @recording_idempotency_key,
        pos_transaction: transaction,
        tender_type_id: @tender_type.id,
        direction: "refunded",
        amount_cents: @amount_cents,
        authorization_code: @proposed_authorization_code,
        terminal_reference: @proposed_terminal_reference,
        original_pos_tender_id: @original_pos_tender&.id
      )

      return nil if outcome.proceed?
      return conflict_result(outcome.pos_tender) if outcome.conflict?

      replay_result(outcome.pos_tender)
    rescue ArgumentError => e
      raise Error, e.message
    end

    def replay_result(existing)
      case existing.status
      when "authorized", "completed"
        Result.new(
          pos_tender: existing, success?: true, error: nil, warnings: [],
          requires_void_confirmation?: false
        )
      when "void_required"
        Result.new(
          pos_tender: existing, success?: false,
          error: existing.void_reason.presence || "void confirmation required",
          warnings: [], requires_void_confirmation?: true
        )
      when "voided"
        Result.new(
          pos_tender: existing, success?: false,
          error: "card tender already voided for this request",
          warnings: [], requires_void_confirmation?: false
        )
      else
        raise Error, "unexpected tender status for recording_idempotency_key (#{existing.status})"
      end
    end

    def conflict_result(existing)
      Result.new(
        pos_tender: existing, success?: false,
        error: CardRecordingIdempotency::CONFLICT_MESSAGE,
        warnings: [], requires_void_confirmation?: false
      )
    end

    def retain_void_required_after_failure!(reason)
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        replay = resolve_recording_idempotency!(transaction)
        return replay if replay

        refs = ValidateTenderReferences::Result.new(
          authorization_code: @proposed_authorization_code,
          terminal_reference: @proposed_terminal_reference,
          reference_1: @proposed_authorization_code,
          reference_2: @proposed_terminal_reference
        )
        retain_void_required!(transaction, refs, reason)
      end
    end

    def retain_void_required!(transaction, refs, reason)
      tender = RetainVoidRequiredCardTender.call(
        pos_transaction: transaction,
        tender_type: @tender_type,
        amount_cents: @amount_cents,
        direction: "refunded",
        refs: refs,
        actor: @actor,
        reason: reason,
        recording_idempotency_key: @recording_idempotency_key,
        original_pos_tender: @original_pos_tender
      )

      if tender.voided?
        return Result.new(
          pos_tender: tender, success?: false,
          error: "card tender already voided for this request",
          warnings: [], requires_void_confirmation?: false
        )
      end

      if tender.authorized? || tender.completed?
        return Result.new(
          pos_tender: tender, success?: true, error: nil, warnings: [],
          requires_void_confirmation?: false
        )
      end

      Result.new(
        pos_tender: tender, success?: false, error: reason, warnings: [],
        requires_void_confirmation?: true
      )
    end

    def failure(message, requires_void_confirmation:)
      Result.new(
        pos_tender: nil, success?: false, error: message, warnings: [],
        requires_void_confirmation?: requires_void_confirmation
      )
    end
  end
end
