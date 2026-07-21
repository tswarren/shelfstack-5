# frozen_string_literal: true

module Inventory
  # Cancels a draft Receipt. Posted receipts have already created inventory
  # and Purchase-Order-line effects and cannot be cancelled here — a posted
  # Receipt requires an explicit reversing correction, which remains
  # deferred (docs/domains/receiving-and-inventory.md, `inventory.receipt.correct`).
  # Idempotent — replaying an already-cancelled Receipt is a no-op success.
  class CancelReceipt < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:receipt, :success?, :error, :replayed)

    def initialize(receipt:, actor:, store:, cancellation_reason: nil)
      @receipt = receipt
      @actor = actor
      @store = store
      @cancellation_reason = cancellation_reason
    end

    def call
      raise Error, "not permitted to cancel receipts" unless authorized?

      ActiveRecord::Base.transaction do
        @receipt.reload.lock!

        if @receipt.cancelled?
          return Result.new(receipt: @receipt, success?: true, error: nil, replayed: true)
        end

        raise Error, "only draft receipts can be cancelled" unless @receipt.draft?
        raise Error, "receipt store mismatch" unless @receipt.store_id == @store.id

        @receipt.update!(
          status: "cancelled",
          cancelled_at: Time.current,
          cancelled_by_user: @actor,
          cancellation_reason: @cancellation_reason
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "inventory.receipt.cancelled",
          subject: @receipt,
          metadata: {
            "receipt_number" => @receipt.receipt_number,
            "cancellation_reason" => @cancellation_reason
          }
        )

        Result.new(receipt: @receipt, success?: true, error: nil, replayed: false)
      end
    rescue Error => e
      Result.new(receipt: @receipt, success?: false, error: e.message, replayed: false)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(receipt: @receipt, success?: false, error: e.record.errors.full_messages.to_sentence, replayed: false)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.receipt.create") == :allow
    end
  end
end
