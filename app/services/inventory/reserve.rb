# frozen_string_literal: true

module Inventory
  class Reserve < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:reservation, :stock_balance, :success?, :error, :warnings)

    def initialize(store:, product_variant:, quantity:, source_type:, source_id:, actor: nil, inventory_unit: nil)
      @store = store
      @product_variant = product_variant
      @quantity = quantity.to_i
      @source_type = source_type.to_s
      @source_id = source_id
      @actor = actor
      @inventory_unit = inventory_unit
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "store/variant organization mismatch" unless @store.organization_id == @product_variant.organization.id

      case @product_variant.inventory_tracking_mode
      when "quantity"
        raise Error, "inventory unit must not be given for quantity-tracked variants" if @inventory_unit.present?

        reserve_quantity
      when "individual"
        raise Error, "quantity must be 1 for individually tracked units" unless @quantity == 1
        raise Error, "inventory unit is required for individually tracked variants" if @inventory_unit.blank?

        reserve_unit
      else
        raise Error, "variant must use quantity or individual inventory tracking"
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(reservation: nil, stock_balance: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def reserve_quantity
      warnings = []

      ActiveRecord::Base.transaction do
        # Lock order: stock balance → reservation (must match ReleaseReservation).
        balance = FindOrCreateStockBalance.call(store: @store, product_variant: @product_variant)
        reservation = InventoryReservation.active.lock.find_by(
          store_id: @store.id,
          product_variant_id: @product_variant.id,
          source_type: @source_type,
          source_id: @source_id
        )

        if reservation
          delta = @quantity - reservation.quantity
          balance.update!(reserved: balance.reserved + delta)
          reservation.update!(quantity: @quantity)
        else
          balance.update!(reserved: balance.reserved + @quantity)
          reservation = InventoryReservation.create!(
            store: @store,
            product_variant: @product_variant,
            source_type: @source_type,
            source_id: @source_id,
            quantity: @quantity,
            status: "active",
            reserved_at: Time.current
          )
        end

        if balance.available.negative?
          warnings << "available quantity is negative after reservation"
        end

        Result.new(
          reservation: reservation,
          stock_balance: balance,
          success?: true,
          error: nil,
          warnings: warnings
        )
      end
    end

    # Individually tracked units are never oversold: the Unit row is locked
    # before its status is checked, so a concurrent reserve of the same Unit
    # serializes behind this transaction and then fails safely (raises rather
    # than double-reserving) once it observes `status: "reserved"`.
    def reserve_unit
      ActiveRecord::Base.transaction do
        # Lock order: unit → reservation (parallel to balance → reservation above).
        unit = InventoryUnit.lock.find(@inventory_unit.id)
        raise Error, "unit belongs to a different store" unless unit.store_id == @store.id
        raise Error, "unit belongs to a different variant" unless unit.product_variant_id == @product_variant.id

        reservation = InventoryReservation.active.lock.find_by(
          store_id: @store.id,
          product_variant_id: @product_variant.id,
          source_type: @source_type,
          source_id: @source_id
        )

        if reservation
          raise Error, "source already reserves a different unit" unless reservation.inventory_unit_id == unit.id
        else
          # `unit.status` is the single authoritative gate (kept in sync with the
          # active Reservation by this service), so this alone rules out double
          # reservation without a second query.
          raise Error, "unit is not available (status: #{unit.status})" unless unit.available?

          unit.update!(status: "reserved")
          reservation = InventoryReservation.create!(
            store: @store,
            product_variant: @product_variant,
            inventory_unit: unit,
            source_type: @source_type,
            source_id: @source_id,
            quantity: 1,
            status: "active",
            reserved_at: Time.current
          )
        end

        Result.new(reservation: reservation, stock_balance: nil, success?: true, error: nil, warnings: [])
      end
    end
  end
end
