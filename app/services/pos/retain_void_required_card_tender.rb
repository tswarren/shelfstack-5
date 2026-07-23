# frozen_string_literal: true

module Pos
  # Internal helper: persists unattachable terminal activity as a durable
  # `void_required` tender using the caller-supplied request idempotency key.
  # Not a separate business workflow.
  module RetainVoidRequiredCardTender
    module_function

    def call(pos_transaction:, tender_type:, amount_cents:, direction:, refs:, actor:, reason:,
             recording_idempotency_key:, original_pos_tender: nil)
      key = recording_idempotency_key.to_s.strip
      raise ArgumentError, "recording_idempotency_key is required" if key.blank?

      existing = PosTender.lock.find_by(recording_idempotency_key: key)
      return existing if existing.present?

      PosTender.create!(
        pos_transaction: pos_transaction,
        store: pos_transaction.store,
        tender_type: tender_type,
        direction: direction,
        status: "void_required",
        amount_cents: amount_cents,
        authorization_code: refs.authorization_code,
        terminal_reference: refs.terminal_reference,
        authorized_at: Time.current,
        void_reason: reason.to_s.truncate(500),
        recording_idempotency_key: key,
        original_pos_tender: original_pos_tender,
        created_by_user: actor
      )
    end
  end
end
