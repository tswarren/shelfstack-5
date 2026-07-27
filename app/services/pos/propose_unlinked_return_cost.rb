# frozen_string_literal: true

module Pos
  # Proposes inventory cost for an inventory-affecting unlinked product return.
  # MAC from the store stock balance first; department estimate second; else unavailable.
  class ProposeUnlinkedReturnCost < ApplicationService
    Result = Data.define(
      :available?,
      :unit_cost_cents,
      :basis_type,
      :method,
      :source,
      :quality,
      :basis_label,
      :error
    )

    def initialize(store:, product_variant:)
      @store = store
      @product_variant = product_variant
    end

    def call
      if @product_variant.blank?
        return unavailable("product variant is required for inventory cost")
      end
      if @product_variant.inventory_tracking_mode == "none"
        return unavailable("non-tracked variants do not require inventory cost")
      end

      balance = StockBalance.find_by(store_id: @store.id, product_variant_id: @product_variant.id)
      mac = balance&.moving_average_cost_cents
      if mac.present? && balance.cost_quality.to_s != "unknown"
        return Result.new(
          available?: true,
          unit_cost_cents: mac,
          basis_type: "moving_average",
          method: "moving_average",
          source: "store_stock_balance_mac",
          quality: "estimated",
          basis_label: "Current store moving average",
          error: nil
        )
      end

      estimate = Inventory::DepartmentEstimate.call(product_variant: @product_variant)
      unless estimate.available
        return unavailable(
          "no inventory cost basis available (MAC and department estimate missing); " \
          "supply an authorized cost basis before inventory-affecting unlinked returns"
        )
      end

      Result.new(
        available?: true,
        unit_cost_cents: estimate.unit_cost_cents,
        basis_type: "configured_estimate",
        method: "configured_estimate",
        source: "department_estimate",
        quality: "estimated",
        basis_label: "Department estimate",
        error: nil
      )
    end

    private

    def unavailable(message)
      Result.new(
        available?: false,
        unit_cost_cents: nil,
        basis_type: nil,
        method: nil,
        source: nil,
        quality: nil,
        basis_label: nil,
        error: message
      )
    end
  end
end
