# frozen_string_literal: true

module Inventory
  class ReleaseReservation < ApplicationService
    Result = Data.define(:reservation, :stock_balance, :success?, :error, :replayed)

    def initialize(reservation:, actor: nil, release_reason: nil)
      @reservation = reservation
      @actor = actor
      @release_reason = release_reason
    end

    def call
      ActiveRecord::Base.transaction do
        @reservation.lock!

        if @reservation.status != "active"
          balance = StockBalance.find_by(store_id: @reservation.store_id, product_variant_id: @reservation.product_variant_id)
          return Result.new(reservation: @reservation, stock_balance: balance, success?: true, error: nil, replayed: true)
        end

        balance = StockBalance.lock.find_by!(
          store_id: @reservation.store_id,
          product_variant_id: @reservation.product_variant_id
        )

        new_reserved = balance.reserved - @reservation.quantity
        raise ActiveRecord::RecordInvalid, balance if new_reserved.negative?

        balance.update!(reserved: new_reserved)
        @reservation.update!(
          status: "released",
          released_at: Time.current,
          released_by_user: @actor,
          release_reason: @release_reason
        )

        Result.new(reservation: @reservation, stock_balance: balance, success?: true, error: nil, replayed: false)
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Result.new(reservation: @reservation, stock_balance: nil, success?: false, error: e.message, replayed: false)
    end
  end
end
