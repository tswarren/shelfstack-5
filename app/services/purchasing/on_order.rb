# frozen_string_literal: true

module Purchasing
  # Derived on-order quantity for a Store × Product Variant:
  # max(ordered − received − cancelled, 0) summed across `ordered` Purchase
  # Orders only (architectural-locks.md#on-order-quantity). Never cached or
  # posted through the inventory ledger.
  class OnOrder < ApplicationService
    def initialize(store:, product_variant:)
      @store = store
      @product_variant = product_variant
    end

    def call
      PurchaseOrderLine
        .joins(:purchase_order)
        .where(purchase_orders: { store_id: @store.id, status: "ordered" })
        .where(product_variant_id: @product_variant.id)
        .sum("GREATEST(ordered_quantity - received_quantity - cancelled_quantity, 0)")
        .to_i
    end
  end
end
