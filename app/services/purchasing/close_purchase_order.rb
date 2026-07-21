# frozen_string_literal: true

module Purchasing
  # Closes an `ordered` Purchase Order once every line's open quantity has
  # reached zero (all quantity received or cancelled). Phase 5 has no reopen
  # workflow (vendors-and-purchasing.md#closing-and-reopening). Idempotent —
  # replaying an already-closed PO is a no-op success.
  class ClosePurchaseOrder < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order, :success?, :error, :replayed)

    def initialize(purchase_order:, actor:, store:)
      @purchase_order = purchase_order
      @actor = actor
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @purchase_order.reload.lock!

        if @purchase_order.closed?
          return Result.new(purchase_order: @purchase_order, success?: true, error: nil, replayed: true)
        end

        raise Error, "only ordered purchase orders can be closed" unless @purchase_order.ordered?
        raise Error, "purchase order store mismatch" unless @purchase_order.store_id == @store.id

        lines = @purchase_order.purchase_order_lines.to_a
        raise Error, "purchase order must have at least one line" if lines.empty?
        unless lines.all? { |line| line.open_quantity.zero? }
          raise Error, "all line quantity must be received or cancelled before closing"
        end

        @purchase_order.update!(status: "closed", closed_at: Time.current, closed_by_user: @actor)

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.purchase_order.closed",
          subject: @purchase_order,
          metadata: { "purchase_order_number" => @purchase_order.purchase_order_number }
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
