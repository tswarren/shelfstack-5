# frozen_string_literal: true

module Pos
  # Cancellation releases provisional reservations (returning request-linked
  # holds to open Product Requests), soft-removes pending lines
  # (so cancelled return lines do not consume returnable quantity), resolves
  # provisional Tender activity, and creates no completed sale/inventory/tax effect.
  class CancelTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error)

    def initialize(pos_transaction:, actor:, reason: nil)
      @pos_transaction = pos_transaction
      @actor = actor
      @reason = reason
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        unless %w[open suspended].include?(transaction.status)
          raise Error, "only open or suspended transactions may be cancelled"
        end

        if transaction.pos_tenders.unresolved.joins(:tender_type)
                      .where(status: "authorized", tender_types: { tender_category: "card" }).exists?
          raise Error,
                "cannot cancel while an authorized card tender remains unresolved; " \
                "confirm the external terminal void first"
        end

        pending_lines = transaction.pos_line_items.pending.order(:id).lock.to_a
        request_ids = pending_lines.filter_map(&:product_request_id).uniq.sort
        locked_requests = request_ids.index_with { |id| ProductRequest.lock.find(id) }

        pending_lines.each do |line|
          next unless line.line_kind == "product"

          reservation = InventoryReservation.active.find_by(source_type: "pos_line_item", source_id: line.id)
          next if reservation.blank?

          product_request = locked_requests[line.product_request_id]
          returned = Pos::ReturnReservationToProductRequest.call(
            reservation: reservation,
            product_request: product_request,
            product_variant: line.product_variant,
            actor: @actor
          )
          raise Error, returned.error unless returned.success?

          next if returned.returned?

          released = Inventory::ReleaseReservation.call(
            reservation: reservation,
            actor: @actor,
            release_reason: @reason || "transaction cancelled"
          )
          raise Error, released.error unless released.success?
        end

        # Soft-remove pending lines so cancelled linked returns no longer consume
        # remaining_returnable_quantity on the original sale line.
        now = Time.current
        pending_lines.each do |line|
          line.update!(
            status: "removed",
            removed_at: now,
            removed_by_user: @actor,
            remove_reason: @reason || "transaction cancelled"
          )
        end

        # ADR-0008: cancellation resolves provisional Tender activity (no completed
        # Tender may survive a cancelled Transaction).
        transaction.pos_tenders.unresolved.find_each do |tender|
          removed = Pos::RemoveTender.call(
            pos_tender: tender, actor: @actor, reason: @reason || "transaction cancelled"
          )
          raise Error, removed.error unless removed.success?
        end

        transaction.update!(
          status: "cancelled",
          cancelled_at: Time.current,
          cancelled_by_user: @actor,
          cancel_reason: @reason
        )

        Result.new(pos_transaction: transaction, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: nil, success?: false, error: e.message)
    end
  end
end
