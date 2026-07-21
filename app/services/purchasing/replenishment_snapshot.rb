# frozen_string_literal: true

module Purchasing
  # Buyer-review replenishment columns for a Store × Product Variant
  # (ordering-and-acquisition-planning.md §4.1): current stock position,
  # derived on-order, current selling price, and expected/last-known cost.
  # Read-only projection — never persisted, never a substitute for
  # Purchasing::OnOrder or StockBalance as the source of truth.
  class ReplenishmentSnapshot < ApplicationService
    Snapshot = Data.define(
      :on_hand, :reserved, :unavailable, :available, :on_order,
      :selling_price_cents, :expected_unit_cost_cents, :last_known_unit_cost_cents
    )

    def initialize(store:, product_variant:)
      @store = store
      @product_variant = product_variant
    end

    def call
      balance = StockBalance.find_by(store_id: @store.id, product_variant_id: @product_variant.id)

      Snapshot.new(
        on_hand: balance&.on_hand || 0,
        reserved: balance&.reserved || 0,
        unavailable: balance&.unavailable || 0,
        available: balance&.available || 0,
        on_order: Purchasing::OnOrder.call(store: @store, product_variant: @product_variant),
        selling_price_cents: @product_variant.regular_price_cents,
        expected_unit_cost_cents: preferred_vendor_source&.expected_unit_cost_cents,
        last_known_unit_cost_cents: balance&.last_known_unit_cost_cents
      )
    end

    private

    def preferred_vendor_source
      ProductVariantVendor
        .where(product_variant_id: @product_variant.id, active: true)
        .order(preferred: :desc, id: :asc)
        .first
    end
  end
end
