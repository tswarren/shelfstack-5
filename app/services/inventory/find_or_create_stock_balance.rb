# frozen_string_literal: true

module Inventory
  # Safe under concurrent first-create on PostgreSQL (create_or_find_by! uses a savepoint).
  class FindOrCreateStockBalance < ApplicationService
    def initialize(store:, product_variant:)
      @store = store
      @product_variant = product_variant
    end

    def call
      balance = StockBalance.create_or_find_by!(store_id: @store.id, product_variant_id: @product_variant.id) do |record|
        record.on_hand = 0
        record.reserved = 0
        record.unavailable = 0
        record.inventory_value_cents = 0
        record.moving_average_cost_cents = nil
        record.cost_quality = "unknown"
      end
      balance.lock!
      balance
    end
  end
end
