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
          returned = return_reservation_to_product_request!(line, reservation, product_request)
          unless returned
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

    private

    def return_reservation_to_product_request!(line, reservation, product_request)
      return false if product_request.blank?
      return false unless product_request.open?
      return false unless product_request.compatible_with_variant?(line.product_variant)

      if reservation.inventory_unit_id.present?
        InventoryUnit.lock.find(reservation.inventory_unit_id)
        locked = InventoryReservation.lock.find(reservation.id)
        return false unless locked.status == "active"

        locked.update!(source_type: "product_request", source_id: product_request.id)
        return true
      end

      # Quantity-tracked: lock balance before reservations; merge coverage in place
      # so we never call Reserve/ReleaseReservation while holding a reservation.
      Inventory::FindOrCreateStockBalance.call(
        store: reservation.store, product_variant: reservation.product_variant
      )
      locked = InventoryReservation.lock.find(reservation.id)
      return false unless locked.status == "active"

      existing = InventoryReservation.active.lock.find_by(
        store_id: locked.store_id,
        product_variant_id: locked.product_variant_id,
        source_type: "product_request",
        source_id: product_request.id
      )
      if existing
        existing.update!(quantity: existing.quantity + locked.quantity)
        locked.update!(
          status: "released",
          released_at: Time.current,
          released_by_user: @actor,
          release_reason: "returned_to_product_request"
        )
        # StockBalance.reserved unchanged — coverage moved between sources.
      else
        locked.update!(source_type: "product_request", source_id: product_request.id)
      end

      true
    end
  end
end
