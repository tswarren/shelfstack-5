# frozen_string_literal: true

module Pos
  # Soft-remove only: retains the line row with status "removed" and releases any
  # active reservation. When the line was fulfilling a still-open Customer
  # Request, returns the commitment to that request rather than dropping it.
  class RemoveLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_line_item:, actor:, reason: nil)
      @pos_line_item = pos_line_item
      @actor = actor
      @reason = reason
    end

    def call
      raise Error, "line is not pending" unless @pos_line_item.pending?
      raise Error, "transaction is not open for editing" unless @pos_line_item.pos_transaction.editable?

      ActiveRecord::Base.transaction do
        # Lock order: POS Transaction → POS Line → Product Request →
        # Stock Balance/Unit → Reservation.
        transaction = PosTransaction.lock.find(@pos_line_item.pos_transaction_id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        line = PosLineItem.lock.find(@pos_line_item.id)
        raise Error, "line is not pending" unless line.pending?
        raise Error, "line does not belong to the locked transaction" unless line.pos_transaction_id == transaction.id

        product_request = nil
        if line.product_request_id.present?
          product_request = ProductRequest.lock.find(line.product_request_id)
        end

        reservation = InventoryReservation.active.find_by(
          source_type: "pos_line_item",
          source_id: line.id
        )
        if reservation
          returned = Pos::ReturnReservationToProductRequest.call(
            reservation: reservation,
            product_request: product_request,
            product_variant: line.product_variant,
            actor: @actor
          )
          raise Error, returned.error unless returned.success?

          unless returned.returned?
            released = Inventory::ReleaseReservation.call(
              reservation: reservation, actor: @actor, release_reason: @reason || "line removed"
            )
            raise Error, released.error unless released.success?
          end
        end

        line.update!(
          status: "removed",
          removed_at: Time.current,
          removed_by_user: @actor,
          remove_reason: @reason
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)

        Result.new(pos_line_item: line, success?: true, error: nil,
                   warnings: (recalculation.blockers + recalculation.warnings).uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end
  end
end
