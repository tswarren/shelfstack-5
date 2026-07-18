# frozen_string_literal: true

module Catalog
  SaleEligibilityResult = Data.define(:blockers, :warnings)

  class SaleEligibility < ApplicationService
    BLOCKERS = %w[
      product_inactive
      variant_inactive
      missing_price
      missing_merchandise_class
      missing_department
      department_not_postable
      missing_tax_category
      unsupported_variant_structure
    ].freeze

    def initialize(variant:, store: nil, as_of: Date.current)
      @variant = variant
      @product = variant.product
      @store = store
      @as_of = as_of
    end

    def call
      blockers = []
      warnings = []

      blockers << "product_inactive" unless product_active?
      blockers << "variant_inactive" unless variant_active?
      blockers << "unsupported_variant_structure" unless @product.variant_structure == "single"
      blockers << "missing_price" if @variant.sellable? && @variant.regular_price_cents.nil?

      merchandise_class = resolved_merchandise_class
      blockers << "missing_merchandise_class" if merchandise_class.nil?

      department = resolved_department(merchandise_class)
      if department.nil?
        blockers << "missing_department"
      elsif !department.active? || !department.postable?
        blockers << "department_not_postable"
      end

      tax_category = resolved_tax_category(merchandise_class, department)
      blockers << "missing_tax_category" if tax_category.nil? || !tax_category.active?

      warnings << "product_outside_availability_window" unless available_on?(@product, @as_of)
      warnings << "variant_outside_availability_window" unless available_on?(@variant, @as_of)

      SaleEligibilityResult.new(blockers: blockers.uniq, warnings: warnings.uniq)
    end

    private

    # Department resolution: variant override → product default → merchandise class default.
    def resolved_department(merchandise_class)
      @variant.department ||
        @product.default_department ||
        merchandise_class&.default_department
    end

    # Tax category resolution: variant override → product default → merchandise class default
    # → department default tax category.
    def resolved_tax_category(merchandise_class, department)
      @variant.tax_category ||
        @product.default_tax_category ||
        merchandise_class&.default_tax_category ||
        department&.default_tax_category
    end

    def resolved_merchandise_class
      @variant.merchandise_class || @product.merchandise_class
    end

    def product_active?
      @product.status == "active" && @product.sellable? && available_on?(@product, @as_of)
    end

    def variant_active?
      @variant.status == "active" && @variant.sellable? && available_on?(@variant, @as_of)
    end

    def available_on?(record, date)
      return false if record.available_from.present? && record.available_from > date
      return false if record.available_until.present? && record.available_until < date

      true
    end
  end
end
