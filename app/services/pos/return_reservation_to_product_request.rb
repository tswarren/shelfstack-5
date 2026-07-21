# frozen_string_literal: true

module Pos
  # Returns an active POS-line Inventory Reservation to an open Product Request.
  # Caller must already hold locks in order: Product Request → (Balance/Unit) …
  # This service does not lock the Product Request itself.
  class ReturnReservationToProductRequest < ApplicationService
    Result = Data.define(:returned?, :success?, :error)

    def initialize(reservation:, product_request:, product_variant:, actor:)
      @reservation = reservation
      @product_request = product_request
      @product_variant = product_variant
      @actor = actor
    end

    def call
      return Result.new(returned?: false, success?: true, error: nil) if @product_request.blank?
      return Result.new(returned?: false, success?: true, error: nil) unless @product_request.open?
      return Result.new(returned?: false, success?: true, error: nil) unless @product_request.compatible_with_variant?(@product_variant)

      if @reservation.inventory_unit_id.present?
        InventoryUnit.lock.find(@reservation.inventory_unit_id)
        locked = InventoryReservation.lock.find(@reservation.id)
        return Result.new(returned?: false, success?: true, error: nil) unless locked.status == "active"

        locked.update!(source_type: "product_request", source_id: @product_request.id)
        return Result.new(returned?: true, success?: true, error: nil)
      end

      Inventory::FindOrCreateStockBalance.call(
        store: @reservation.store, product_variant: @reservation.product_variant
      )
      locked = InventoryReservation.lock.find(@reservation.id)
      return Result.new(returned?: false, success?: true, error: nil) unless locked.status == "active"

      existing = InventoryReservation.active.lock.find_by(
        store_id: locked.store_id,
        product_variant_id: locked.product_variant_id,
        source_type: "product_request",
        source_id: @product_request.id
      )
      if existing
        existing.update!(quantity: existing.quantity + locked.quantity)
        locked.update!(
          status: "released",
          released_at: Time.current,
          released_by_user: @actor,
          release_reason: "returned_to_product_request"
        )
      else
        locked.update!(source_type: "product_request", source_id: @product_request.id)
      end

      Result.new(returned?: true, success?: true, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(returned?: false, success?: false, error: e.record.errors.full_messages.to_sentence)
    end
  end
end
