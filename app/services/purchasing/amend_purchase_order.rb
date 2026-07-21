# frozen_string_literal: true

module Purchasing
  # Permitted amendments to an already-placed (`ordered`) Purchase Order:
  # increase supply by adding new lines, or reduce expected quantity on an
  # existing line via `cancelled_quantity` with a reason
  # (vendors-and-purchasing.md#mutability-after-placement). Never edits
  # ordered_quantity, cost, or other line-identity fields in place.
  #
  # Coordinates with Purchase-Order Allocations (OD-007): a line's open
  # quantity may never drop below its remaining allocated quantity. When
  # cancelling quantity would do that, the caller must also pass
  # `release_allocations_attributes` covering the shortfall (applied
  # atomically, before the cancellation is checked) — otherwise the whole
  # amendment is rejected.
  class AmendPurchaseOrder < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order, :success?, :error)

    def initialize(purchase_order:, actor:, store:, cancel_lines_attributes: [], new_lines_attributes: [],
                    release_allocations_attributes: [], reason: nil)
      @purchase_order = purchase_order
      @actor = actor
      @store = store
      @cancel_lines_attributes = Array(cancel_lines_attributes)
      @new_lines_attributes = Array(new_lines_attributes)
      @release_allocations_attributes = Array(release_allocations_attributes)
      @reason = reason
    end

    def call
      ActiveRecord::Base.transaction do
        @purchase_order.reload.lock!

        raise Error, "only ordered purchase orders can be amended" unless @purchase_order.ordered?
        raise Error, "purchase order store mismatch" unless @purchase_order.store_id == @store.id

        released = apply_allocation_releases!
        cancelled = apply_cancellations!
        raise Error, "a reason is required to cancel ordered quantity" if cancelled.any? && @reason.blank?

        added = add_new_lines!
        if cancelled.empty? && added.empty? && released.empty?
          raise Error, "amend must cancel quantity or add at least one line"
        end

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.purchase_order.amended",
          subject: @purchase_order,
          metadata: {
            "reason" => @reason,
            "cancelled_lines" => cancelled,
            "added_line_ids" => added.map(&:id),
            "released_allocations" => released
          }
        )

        Result.new(purchase_order: @purchase_order.reload, success?: true, error: nil)
      end
    rescue Error => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.record.errors.full_messages.to_sentence)
    end

    private

    # Applied before cancellations so a caller can atomically release exactly
    # enough allocated quantity to permit a requested cancellation.
    def apply_allocation_releases!
      @release_allocations_attributes.filter_map do |attrs|
        attrs = attrs.to_h.symbolize_keys
        allocation = PurchaseOrderAllocation.lock.find(attrs[:allocation_id] || attrs[:id])
        unless allocation.purchase_order_line.purchase_order_id == @purchase_order.id
          raise Error, "allocation ##{allocation.id} does not belong to this purchase order"
        end

        quantity = attrs[:quantity].to_i
        next nil unless quantity.positive?

        reason = attrs[:reason].presence || "line_quantity_cancelled"
        allocation.release!(quantity: quantity, reason: reason, actor: @actor, note: attrs[:note])
        { "allocation_id" => allocation.id, "quantity" => quantity, "reason" => reason }
      end
    rescue ArgumentError => e
      raise Error, e.message
    end

    def apply_cancellations!
      @cancel_lines_attributes.filter_map do |attrs|
        attrs = attrs.to_h.symbolize_keys
        line = @purchase_order.purchase_order_lines.lock.find(attrs[:id] || attrs[:line_id])
        new_cancelled = attrs[:cancelled_quantity].to_i

        next nil if new_cancelled == line.cancelled_quantity

        raise Error, "cancelled quantity cannot decrease for line ##{line.id}" if new_cancelled < line.cancelled_quantity
        raise Error, "cancelled quantity cannot exceed ordered quantity for line ##{line.id}" if new_cancelled > line.ordered_quantity

        new_open = [ line.ordered_quantity - line.received_quantity - new_cancelled, 0 ].max
        remaining_allocated = remaining_allocated_for_line(line.id)
        if new_open < remaining_allocated
          raise Error, "cannot reduce line ##{line.id} open quantity to #{new_open}; #{remaining_allocated} " \
                       "quantity remains allocated to customer requests — release allocations first"
        end

        previous = line.cancelled_quantity
        line.update!(cancelled_quantity: new_cancelled)
        { "line_id" => line.id, "from" => previous, "to" => new_cancelled }
      end
    end

    def remaining_allocated_for_line(line_id)
      PurchaseOrderAllocation.where(purchase_order_line_id: line_id)
        .includes(:purchase_order_allocation_events).sum(&:remaining_quantity)
    end

    def add_new_lines!
      base_position = (@purchase_order.purchase_order_lines.maximum(:position) || -1) + 1

      @new_lines_attributes.each_with_index.map do |attrs, index|
        attrs = attrs.to_h.symbolize_keys.except(:id, :purchase_order_id)
        line = @purchase_order.purchase_order_lines.build(attrs)
        line.position = attrs[:position].presence || (base_position + index)
        line.cost_provenance ||= "amendment"
        LineSnapshot.apply!(line)
        line.save!
        line
      end
    end
  end
end
