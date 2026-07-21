# frozen_string_literal: true

module Purchasing
  # Bulk-edits discount on selected draft `discount_from_list` lines with an
  # audit trail (vendors-and-purchasing.md#expected-cost). Expected unit/extended
  # cost recompute deterministically via `PurchaseOrderLine`'s cost callback.
  # Automatic tier qualification remains deferred.
  class ApplyBulkDiscountToDraftLines < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order, :success?, :error, :updated_line_ids)

    def initialize(purchase_order:, line_ids:, discount_bps:, actor:, store:)
      @purchase_order = purchase_order
      @line_ids = Array(line_ids).map(&:to_i)
      @discount_bps = discount_bps.to_i
      @actor = actor
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @purchase_order.reload.lock!

        raise Error, "only draft purchase orders can be bulk-edited" unless @purchase_order.draft?
        raise Error, "purchase order store mismatch" unless @purchase_order.store_id == @store.id
        raise Error, "select at least one line" if @line_ids.empty?

        lines = @purchase_order.purchase_order_lines.where(id: @line_ids, cost_entry_method: "discount_from_list")
        raise Error, "no eligible discount-from-list lines were selected" if lines.empty?

        updated_ids = lines.map do |line|
          line.update!(discount_bps: @discount_bps, cost_provenance: "bulk_discount_update")
          line.id
        end

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.purchase_order.bulk_discount_applied",
          subject: @purchase_order,
          metadata: { "discount_bps" => @discount_bps, "line_ids" => updated_ids }
        )

        Result.new(purchase_order: @purchase_order.reload, success?: true, error: nil, updated_line_ids: updated_ids)
      end
    rescue Error => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.message, updated_line_ids: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.record.errors.full_messages.to_sentence,
                  updated_line_ids: [])
    end
  end
end
