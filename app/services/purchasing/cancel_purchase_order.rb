# frozen_string_literal: true

module Purchasing
  # Whole-PO cancellation applies only when nothing has been received
  # (architectural-locks.md#purchase-order-commercial-lifecycle-phase-5).
  # A partially received PO must reduce remaining quantity through
  # `AmendPurchaseOrder` instead. Idempotent — replaying an already-cancelled
  # PO is a no-op success.
  class CancelPurchaseOrder < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order, :success?, :error, :replayed)

    def initialize(purchase_order:, actor:, store:, cancel_reason: nil)
      @purchase_order = purchase_order
      @actor = actor
      @store = store
      @cancel_reason = cancel_reason
    end

    def call
      ActiveRecord::Base.transaction do
        @purchase_order.reload.lock!

        if @purchase_order.cancelled?
          return Result.new(purchase_order: @purchase_order, success?: true, error: nil, replayed: true)
        end

        raise Error, "closed purchase orders cannot be cancelled" if @purchase_order.closed?
        raise Error, "purchase order store mismatch" unless @purchase_order.store_id == @store.id

        if @purchase_order.purchase_order_lines.where("received_quantity > 0").exists?
          raise Error, "cannot cancel a purchase order with received quantity; amend it to cancel remaining open quantity"
        end

        @purchase_order.update!(status: "cancelled", cancelled_at: Time.current, cancelled_by_user: @actor)

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.purchase_order.cancelled",
          subject: @purchase_order,
          metadata: {
            "purchase_order_number" => @purchase_order.purchase_order_number,
            "cancel_reason" => @cancel_reason
          }
        )

        Result.new(purchase_order: @purchase_order, success?: true, error: nil, replayed: false)
      end
    rescue Error => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.message, replayed: false)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.record.errors.full_messages.to_sentence,
                  replayed: false)
    end
  end
end
