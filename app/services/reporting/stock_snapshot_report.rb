# frozen_string_literal: true

module Reporting
  class StockSnapshotReport < ApplicationService
    Row = Data.define(
      :product_variant, :on_hand, :reserved, :unavailable, :available, :on_order,
      :as_of, :inventory_value_cents, :cost_quality
    )

    def initialize(store:)
      @store = store
    end

    def call
      as_of = Time.current
      balances = StockBalance.where(store_id: @store.id).includes(product_variant: :product).order(:id)
      balances.map do |balance|
        on_order = Purchasing::OnOrder.call(store: @store, product_variant: balance.product_variant)
        Row.new(
          product_variant: balance.product_variant,
          on_hand: balance.on_hand,
          reserved: balance.reserved,
          unavailable: balance.unavailable,
          available: balance.on_hand - balance.reserved - balance.unavailable,
          on_order: on_order,
          as_of: as_of,
          inventory_value_cents: balance.inventory_value_cents,
          cost_quality: balance.cost_quality
        )
      end
    end
  end
end
