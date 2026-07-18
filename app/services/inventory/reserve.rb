# frozen_string_literal: true

module Inventory
  class Reserve < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:reservation, :stock_balance, :success?, :error, :warnings)

    def initialize(store:, product_variant:, quantity:, source_type:, source_id:, actor: nil)
      @store = store
      @product_variant = product_variant
      @quantity = quantity.to_i
      @source_type = source_type.to_s
      @source_id = source_id
      @actor = actor
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "variant must be quantity-tracked" unless @product_variant.inventory_tracking_mode == "quantity"
      raise Error, "store/variant organization mismatch" unless @store.organization_id == @product_variant.organization.id

      warnings = []

      ActiveRecord::Base.transaction do
        balance = find_or_create_and_lock_balance!
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
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(reservation: nil, stock_balance: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def find_or_create_and_lock_balance!
      balance = StockBalance.find_by(store_id: @store.id, product_variant_id: @product_variant.id)
      unless balance
        begin
          balance = StockBalance.create!(
            store: @store,
            product_variant: @product_variant,
            on_hand: 0,
            reserved: 0,
            unavailable: 0,
            inventory_value_cents: 0,
            cost_quality: "unknown"
          )
        rescue ActiveRecord::RecordNotUnique
          balance = StockBalance.find_by!(store_id: @store.id, product_variant_id: @product_variant.id)
        end
      end
      balance.lock!
      balance
    end
  end
end
