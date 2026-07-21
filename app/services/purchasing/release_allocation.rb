# frozen_string_literal: true

module Purchasing
  # Releases remaining Purchase-Order Allocation quantity that no longer
  # represents usable expected supply for its Customer Request (OD-007).
  # Appends a `released` PurchaseOrderAllocationEvent with a structured
  # reason code; never rewrites or deletes prior events. Releasing does not
  # itself reopen or otherwise change the Product Request — the request's
  # uncovered quantity simply increases because remaining allocated quantity
  # decreases (ADR-0015 §10).
  #
  # Locks the Purchase-Order Allocation row before recomputing remaining
  # quantity so concurrent releases (or a concurrent conversion) against the
  # same allocation cannot both succeed past the remaining quantity.
  # Idempotent when called with a `posting_key`: replaying the same key is a
  # no-op success; reusing a key with different quantity/reason is a conflict.
  class ReleaseAllocation < ApplicationService
    Error = Class.new(StandardError)
    ConflictError = Class.new(Error)
    Result = Data.define(:purchase_order_allocation, :event, :success?, :error, :replayed)

    def initialize(purchase_order_allocation:, quantity:, reason:, actor:, store:, note: nil, occurred_at: nil, posting_key: nil)
      @purchase_order_allocation = purchase_order_allocation
      @quantity = quantity.to_i
      @reason = reason.to_s
      @actor = actor
      @store = store
      @note = note
      @occurred_at = occurred_at || Time.current
      @posting_key = posting_key.presence
    end

    def call
      raise Error, "not permitted to release purchase-order allocations" unless authorized?
      raise Error, "purchase order allocation is required" if @purchase_order_allocation.blank?
      raise Error, "quantity must be a positive integer" unless @quantity.positive?
      unless PurchaseOrderAllocationEvent::RELEASE_REASONS.include?(@reason)
        raise Error, "reason must be one of #{PurchaseOrderAllocationEvent::RELEASE_REASONS.join(', ')}"
      end

      if @posting_key.present?
        existing = PurchaseOrderAllocationEvent.find_by(posting_key: @posting_key)
        return replay_or_conflict!(existing) if existing
      end

      ActiveRecord::Base.transaction do
        # Lock order: Purchase Order → Purchase Order Line → Product Request → Allocation.
        line = @purchase_order_allocation.purchase_order_line
        PurchaseOrder.lock.find(line.purchase_order_id)
        PurchaseOrderLine.lock.find(line.id)
        ProductRequest.lock.find(@purchase_order_allocation.product_request_id)
        allocation = PurchaseOrderAllocation.lock.find(@purchase_order_allocation.id)
        store_id = allocation.purchase_order_line.purchase_order.store_id
        raise Error, "purchase order allocation store mismatch" unless store_id == @store.id

        event = allocation.release!(
          quantity: @quantity, reason: @reason, actor: @actor, note: @note,
          occurred_at: @occurred_at, posting_key: @posting_key
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.allocation.released",
          subject: allocation,
          metadata: { "quantity" => @quantity, "reason" => @reason, "note" => @note }
        )

        Result.new(purchase_order_allocation: allocation.reload, event: event, success?: true, error: nil, replayed: false)
      end
    rescue ActiveRecord::RecordNotUnique
      existing = PurchaseOrderAllocationEvent.find_by!(posting_key: @posting_key)
      replay_or_conflict!(existing)
    rescue Error, ArgumentError => e
      Result.new(purchase_order_allocation: @purchase_order_allocation, event: nil, success?: false, error: e.message,
                  replayed: false)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order_allocation: @purchase_order_allocation, event: nil, success?: false,
                  error: e.record.errors.full_messages.to_sentence, replayed: false)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "purchasing.allocation.release") == :allow
    end

    def replay_or_conflict!(existing)
      unless existing.purchase_order_allocation_id == @purchase_order_allocation&.id &&
             existing.quantity == @quantity && existing.reason == @reason
        raise ConflictError, "posting_key #{@posting_key} already used with different intent"
      end

      Result.new(purchase_order_allocation: existing.purchase_order_allocation.reload, event: existing,
                  success?: true, error: nil, replayed: true)
    end
  end
end
