# frozen_string_literal: true

module Pos
  class UpdateLineQty < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_line_item:, quantity:, actor:)
      @pos_line_item = pos_line_item
      @quantity = quantity.to_i
      @actor = actor
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "line is not pending" unless @pos_line_item.pending?
      raise Error, "transaction is not open for editing" unless @pos_line_item.pos_transaction.editable?
      if @pos_line_item.return?
        raise Error, "linked return quantity cannot be edited; remove and re-add the return line"
      end
      if individually_tracked?(@pos_line_item)
        raise Error, "quantity is fixed at 1 for individually tracked lines"
      end

      warnings = []

      ActiveRecord::Base.transaction do
        # Canonical order: transaction before line (matches completion lock order).
        transaction = PosTransaction.lock.find(@pos_line_item.pos_transaction_id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        line = PosLineItem.lock.find(@pos_line_item.id)
        raise Error, "line is not pending" unless line.pending?
        raise Error, "line does not belong to the locked transaction" unless line.pos_transaction_id == transaction.id
        if line.return?
          raise Error, "linked return quantity cannot be edited; remove and re-add the return line"
        end

        product_request = nil
        if line.product_request_id.present?
          product_request = ProductRequest.lock.find(line.product_request_id)
          raise Error, "product request is not open" unless product_request.open?
          unless product_request.compatible_with_variant?(line.product_variant)
            raise Error, product_request.compatibility_error_for(line.product_variant)
          end

          outstanding = product_request.outstanding_quantity
          if @quantity > outstanding
            raise Error, "quantity exceeds the product request's outstanding quantity (#{outstanding} outstanding)"
          end

          current_pos_qty = InventoryReservation.active.where(
            source_type: "pos_line_item", source_id: line.id
          ).sum(:quantity)
          transferable = InventoryReservation.active.where(
            store_id: transaction.store_id,
            product_variant_id: line.product_variant_id,
            source_type: "product_request",
            source_id: product_request.id
          ).sum(:quantity)
          # POS quantity already counted in coverage may grow using request-held
          # transfer first; only net-new free stock is capped by uncovered.
          delta = @quantity - current_pos_qty
          if delta.positive?
            additional = [ delta - transferable, 0 ].max
            uncovered = product_request.uncovered_quantity
            if additional > uncovered
              raise Error, "quantity exceeds the product request's uncovered quantity (#{uncovered} uncovered)"
            end
          end
        end

        if line.line_kind == "product" && line.product_variant.inventory_tracking_mode == "quantity"
          warnings.concat(adjust_quantity_reservation!(transaction.store, line, product_request))
        end

        line.update!(quantity: @quantity)

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        warnings.concat(recalculation.blockers).concat(recalculation.warnings)

        Result.new(pos_line_item: line, success?: true, error: nil, warnings: warnings.uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def individually_tracked?(line)
      line.line_kind == "product" && line.product_variant&.inventory_tracking_mode == "individual"
    end

    # Lock order: stock balance → reservations. When a Customer Request is linked,
    # decreasing returns coverage to the request; increasing prefers transferring
    # remaining request-held quantity before reserving free stock.
    def adjust_quantity_reservation!(store, line, product_request)
      balance = Inventory::FindOrCreateStockBalance.call(store: store, product_variant: line.product_variant)
      pos_reservation = InventoryReservation.active.lock.find_by(
        store_id: store.id, product_variant_id: line.product_variant_id,
        source_type: "pos_line_item", source_id: line.id
      )
      raise Error, "no reservation found for line" if pos_reservation.blank?

      request_reservation = if product_request
        InventoryReservation.active.lock.find_by(
          store_id: store.id, product_variant_id: line.product_variant_id,
          source_type: "product_request", source_id: product_request.id
        )
      end

      delta = @quantity - pos_reservation.quantity
      return available_warning(balance) if delta.zero?

      if delta.positive?
        increase_reservation!(balance, pos_reservation, request_reservation, delta)
      else
        decrease_reservation!(balance, pos_reservation, request_reservation, product_request, -delta)
      end

      available_warning(balance.reload)
    end

    def increase_reservation!(balance, pos_reservation, request_reservation, delta)
      from_request = [ request_reservation&.quantity.to_i, delta ].min
      if from_request.positive?
        remaining_request = request_reservation.quantity - from_request
        if remaining_request.zero?
          request_reservation.update!(
            status: "released",
            released_at: Time.current,
            released_by_user: @actor,
            release_reason: "transferred_to_pos"
          )
        else
          request_reservation.update!(quantity: remaining_request)
        end
        # Transfer does not change StockBalance.reserved.
        pos_reservation.update!(quantity: pos_reservation.quantity + from_request)
      end

      still_need = delta - from_request
      return unless still_need.positive?

      balance.update!(reserved: balance.reserved + still_need)
      pos_reservation.update!(quantity: pos_reservation.quantity + still_need)
    end

    def decrease_reservation!(balance, pos_reservation, request_reservation, product_request, return_qty)
      pos_reservation.update!(quantity: pos_reservation.quantity - return_qty)

      if product_request
        if request_reservation
          request_reservation.update!(quantity: request_reservation.quantity + return_qty)
        else
          InventoryReservation.create!(
            store_id: pos_reservation.store_id,
            product_variant_id: pos_reservation.product_variant_id,
            source_type: "product_request",
            source_id: product_request.id,
            quantity: return_qty,
            status: "active",
            reserved_at: Time.current
          )
        end
        # Returning coverage to the request does not change StockBalance.reserved.
      else
        new_reserved = balance.reserved - return_qty
        raise Error, "reserved quantity would go negative" if new_reserved.negative?

        balance.update!(reserved: new_reserved)
      end

      if pos_reservation.quantity.zero?
        pos_reservation.update!(
          status: "released",
          released_at: Time.current,
          released_by_user: @actor,
          release_reason: "line quantity reduced"
        )
      end
    end

    def available_warning(balance)
      balance.available.negative? ? [ "available quantity is negative after reservation" ] : []
    end
  end
end
