# frozen_string_literal: true

module Inventory
  # Resolves optional Department margin estimate for opening inventory.
  class DepartmentEstimate < ApplicationService
    Result = Data.define(
      :available,
      :department,
      :regular_price_cents,
      :margin_bps,
      :unit_cost_cents,
      :error
    )

    def initialize(product_variant:)
      @product_variant = product_variant
    end

    def call
      department = resolve_department
      return unavailable("department unavailable") if department.blank?

      margin = department.default_cost_estimation_margin_bps
      return unavailable("margin unavailable") if margin.nil?

      price = @product_variant.regular_price_cents
      return unavailable("regular price unavailable") if price.nil?

      unit_cost = Rounding.round_half_up(price * (10_000 - margin), 10_000)

      Result.new(
        available: true,
        department: department,
        regular_price_cents: price,
        margin_bps: margin,
        unit_cost_cents: unit_cost,
        error: nil
      )
    end

    private

    def resolve_department
      product = @product_variant.product
      merchandise_class = @product_variant.merchandise_class || product.merchandise_class

      @product_variant.department ||
        product.default_department ||
        merchandise_class&.default_department
    end

    def unavailable(message)
      Result.new(
        available: false,
        department: nil,
        regular_price_cents: nil,
        margin_bps: nil,
        unit_cost_cents: nil,
        error: message
      )
    end
  end
end
