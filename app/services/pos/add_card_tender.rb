# frozen_string_literal: true

module Pos
  # Records an operator-confirmed standalone-terminal card payment.
  # ShelfStack does not drive the terminal; ADR-0009 confirm-before-complete.
  #
  # Amount must satisfy 0 < amount <= remaining received balance (unless the
  # tender type allows over-tender). Once tender-type references validate, any
  # later business failure that prevents attachment persists a `void_required`
  # tender so terminal activity is never discarded.
  #
  # `recording_idempotency_key` is a client-generated request UUID shared by the
  # authorized or void_required outcome (ADR-0016 request idempotency).
  class AddCardTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings, :requires_void_confirmation?)

    def initialize(pos_transaction:, tender_type:, amount_cents:, actor:,
                   recording_idempotency_key: nil,
                   authorization_code: nil, terminal_reference: nil,
                   reference_1: nil, reference_2: nil)
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      # Client-supplied request UUID preferred; generate only when callers omit it
      # (tests / internal). Forms must post a stable key for double-submit safety.
      @recording_idempotency_key = recording_idempotency_key.to_s.strip.presence || SecureRandom.uuid
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @reference_1 = reference_1
      @reference_2 = reference_2
      @actor = actor
    end


    def call
      refs = begin
        validate_structure_and_references!
      rescue Error, ValidateTenderReferences::Error => e
        return failure(e.message, requires_void_confirmation: false)
      end

      attach_authorized!(refs)
    rescue Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      retain_void_required_after_failure!(refs, e.message)
    end

    private

    def validate_structure_and_references!
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "amount must be positive" unless @amount_cents.positive?

      ValidateTenderReferences.call(

        tender_type: @tender_type,
        reference_1: @reference_1,
        reference_2: @reference_2,
        authorization_code: @authorization_code,
        terminal_reference: @terminal_reference
      )
    end

    def attach_authorized!(refs)
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        replay = resolve_recording_idempotency!(transaction)
        return replay if replay

        unless transaction.open?
          return retain_void_required!(transaction, refs, "transaction is not open")
        end

        TenderGuards.assert_active!(@tender_type)
        TenderGuards.assert_payment_enabled!(@tender_type)

        recalculation = recalculate_for_tender!(transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        balance_due = TenderGuards.remaining_received_balance_cents(transaction, recalculation.net_total_cents)
        raise Error, "no balance due" if balance_due.zero?

        if !@tender_type.allows_over_tender? && @amount_cents > balance_due
          raise Error,
                "amount exceeds remaining balance (#{balance_due}); confirm external void and record as voided"
        end

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "received", status: "authorized", amount_cents: @amount_cents,
          authorization_code: refs.authorization_code, terminal_reference: refs.terminal_reference,
          authorized_at: Time.current, created_by_user: @actor,
          recording_idempotency_key: @recording_idempotency_key
        )

        Result.new(
          pos_tender: tender, success?: true, error: nil, warnings: recalculation.warnings,
          requires_void_confirmation?: false
        )
      end
    end

    def resolve_recording_idempotency!(transaction)
      existing = PosTender.lock.find_by(recording_idempotency_key: @recording_idempotency_key)
      return nil if existing.blank?

      if existing.pos_transaction_id != transaction.id
        raise Error, "recording_idempotency_key belongs to another transaction"
      end

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

    def retain_void_required_after_failure!(refs, reason)
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        replay = resolve_recording_idempotency!(transaction)
        return replay if replay

        retain_void_required!(transaction, refs, reason)
      end
    end

    def retain_void_required!(transaction, refs, reason)
      tender = RetainVoidRequiredCardTender.call(
        pos_transaction: transaction,
        tender_type: @tender_type,
        amount_cents: @amount_cents,
        direction: "received",
        refs: refs,
        actor: @actor,
        reason: reason,
        recording_idempotency_key: @recording_idempotency_key
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

    def recalculate_for_tender!(transaction)
      if transaction.pos_line_items.pending.returns.where.not(original_pos_line_item_id: nil).exists?
        FinalizeReturnFinancials.call(pos_transaction: transaction).recalculation
      else
        RecalculateTransaction.call(pos_transaction: transaction)
      end
    end

    def failure(message, requires_void_confirmation:)
      Result.new(
        pos_tender: nil, success?: false, error: message, warnings: [],
        requires_void_confirmation?: requires_void_confirmation
      )
    end
  end
end
