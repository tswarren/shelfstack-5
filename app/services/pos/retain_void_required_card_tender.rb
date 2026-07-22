# frozen_string_literal: true

require "digest"

module Pos
  # Persists unattachable terminal activity as a durable `void_required` tender
  # so references are never discarded after successful reference validation.
  # Idempotent on recording_idempotency_key.
  module RetainVoidRequiredCardTender
    module_function

    def call(pos_transaction:, tender_type:, amount_cents:, direction:, refs:, actor:, reason:)
      key = idempotency_key(
        pos_transaction_id: pos_transaction.id,
        direction: direction,
        amount_cents: amount_cents,
        authorization_code: refs.authorization_code,
        terminal_reference: refs.terminal_reference
      )

      existing = PosTender.find_by(recording_idempotency_key: key)
      return existing if existing.present? # void_required or already voided (retry)

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
        created_by_user: actor
      )
    end

    def idempotency_key(pos_transaction_id:, direction:, amount_cents:, authorization_code:, terminal_reference:)
      Digest::SHA256.hexdigest(
        [
          "void_required",
          pos_transaction_id,
          direction,
          amount_cents.to_i,
          authorization_code.to_s,
          terminal_reference.to_s
        ].join("|")
      )
    end
  end
end
