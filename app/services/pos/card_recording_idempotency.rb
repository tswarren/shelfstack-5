# frozen_string_literal: true

module Pos
  # Shared request-UUID replay / conflict checks for AddCardTender and
  # AddCardRefundTender. Compares the incoming payload to the stored tender
  # before treating a key as an idempotent replay (ADR-0016).
  module CardRecordingIdempotency
    CONFLICT_MESSAGE =
      "This card-recording request key was already used with different details. " \
      "The new terminal activity was not recorded. Verify and void the external " \
      "operation before retrying from a newly loaded form."

    Outcome = Data.define(:kind, :pos_tender) do
      def proceed? = kind == :proceed
      def conflict? = kind == :conflict
      def replay? = kind == :replay
    end

    module_function

    def normalize_reference(value)
      value.to_s.strip.presence
    end

    # Locks any existing keyed tender. Caller must already hold the transaction lock.
    def resolve!(
      recording_idempotency_key:,
      pos_transaction:,
      tender_type_id:,
      direction:,
      amount_cents:,
      authorization_code:,
      terminal_reference:,
      original_pos_tender_id: nil
    )
      key = recording_idempotency_key.to_s.strip
      raise ArgumentError, "recording_idempotency_key is required" if key.blank?

      existing = PosTender.lock.find_by(recording_idempotency_key: key)
      return Outcome.new(kind: :proceed, pos_tender: nil) if existing.blank?

      if existing.pos_transaction_id != pos_transaction.id
        raise ArgumentError, "recording_idempotency_key belongs to another transaction"
      end

      unless same_request?(
        existing: existing,
        tender_type_id: tender_type_id,
        direction: direction,
        amount_cents: amount_cents,
        authorization_code: authorization_code,
        terminal_reference: terminal_reference,
        original_pos_tender_id: original_pos_tender_id
      )
        return Outcome.new(kind: :conflict, pos_tender: existing)
      end

      Outcome.new(kind: :replay, pos_tender: existing)
    end

    def same_request?(
      existing:,
      tender_type_id:,
      direction:,
      amount_cents:,
      authorization_code:,
      terminal_reference:,
      original_pos_tender_id: nil
    )
      existing.tender_type_id == tender_type_id &&
        existing.direction == direction.to_s &&
        existing.amount_cents == amount_cents.to_i &&
        normalize_reference(existing.authorization_code) == normalize_reference(authorization_code) &&
        normalize_reference(existing.terminal_reference) == normalize_reference(terminal_reference) &&
        existing.original_pos_tender_id == original_pos_tender_id
    end
  end
end
