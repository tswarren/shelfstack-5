# frozen_string_literal: true

module Purchasing
  # Transitions a draft Purchase Order to `ordered`: validates Store/Vendor and
  # line state, records placement User/time, and begins counting open quantity
  # in derived On Order (vendors-and-purchasing.md#place-order). Idempotent —
  # replaying an already-ordered PO is a no-op success.
  class PlacePurchaseOrder < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order, :success?, :error, :replayed, :warnings)

    def initialize(purchase_order:, actor:, store:)
      @purchase_order = purchase_order
      @actor = actor
      @store = store
    end

    def call
      unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "purchasing.purchase_order.place") == :allow
        return Result.new(purchase_order: @purchase_order, success?: false, error: "not permitted to place purchase orders", replayed: false, warnings: [])
      end

      ActiveRecord::Base.transaction do
        @purchase_order.reload.lock!

        if @purchase_order.ordered?
          return Result.new(purchase_order: @purchase_order, success?: true, error: nil, replayed: true, warnings: [])
        end

        raise Error, "only draft purchase orders can be placed" unless @purchase_order.draft?
        raise Error, "purchase order store mismatch" unless @purchase_order.store_id == @store.id
        raise Error, "vendor must be active" unless @purchase_order.vendor.active?

        lines = @purchase_order.purchase_order_lines.to_a
        raise Error, "purchase order must have at least one line" if lines.empty?

        lines.each do |line|
          raise Error, line.errors.full_messages.to_sentence unless line.valid?
        end

        warnings = ThresholdWarnings.call(lines)

        @purchase_order.update!(
          status: "ordered",
          ordered_at: Time.current,
          ordered_by_user: @actor,
          ordered_on: @purchase_order.ordered_on || StoreTime.today(@store)
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.purchase_order.placed",
          subject: @purchase_order,
          metadata: {
            "purchase_order_number" => @purchase_order.purchase_order_number,
            "vendor_id" => @purchase_order.vendor_id,
            "line_count" => lines.size,
            "warnings" => warnings
          }
        )

        Result.new(purchase_order: @purchase_order, success?: true, error: nil, replayed: false, warnings: warnings)
      end
    rescue Error => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.message, replayed: false, warnings: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.record.errors.full_messages.to_sentence,
                  replayed: false, warnings: [])
    end
  end
end
