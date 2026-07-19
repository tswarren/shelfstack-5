# frozen_string_literal: true

module Catalog
  SaleEligibilityResult = Data.define(:blockers, :warnings)

  # Catalog readiness only — not full POS authorization.
  class SaleEligibility < ApplicationService
    BLOCKERS = %w[
      product_inactive
      product_not_sellable
      product_outside_availability_window
      variant_inactive
      variant_not_sellable
      variant_outside_availability_window
      missing_price
      missing_tracking_mode
      missing_merchandise_class
      merchandise_class_inactive
      missing_department
      department_inactive
      department_not_postable
      missing_tax_category
      tax_category_inactive
      missing_product_type
      missing_product_format
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

      blockers << "product_inactive" unless @product.status == "active"
      blockers << "product_not_sellable" unless @product.sellable?
      blockers << "product_outside_availability_window" unless available_on?(@product, @as_of)

      blockers << "variant_inactive" unless @variant.status == "active"
      blockers << "variant_not_sellable" unless @variant.sellable?
      blockers << "variant_outside_availability_window" unless available_on?(@variant, @as_of)

      blockers << "unsupported_variant_structure" unless @product.variant_structure == "single"
      blockers << "missing_product_type" if @product.product_type.blank?
      blockers << "missing_product_format" if @product.product_format_id.blank?
      blockers << "missing_tracking_mode" if @variant.inventory_tracking_mode.blank?
      blockers << "missing_price" if @variant.sellable? && @variant.regular_price_cents.nil?

      merchandise_class = classification.merchandise_class
      if merchandise_class.nil?
        blockers << "missing_merchandise_class"
      elsif !merchandise_class.active?
        blockers << "merchandise_class_inactive"
      end

      department = classification.department
      if department.nil?
        blockers << "missing_department"
      else
        blockers << "department_inactive" unless department.active?
        blockers << "department_not_postable" unless department.postable?
      end

      tax_category = classification.tax_category
      if tax_category.nil?
        blockers << "missing_tax_category"
      elsif !tax_category.active?
        blockers << "tax_category_inactive"
      end

      # Store context is reserved for later POS/store-policy checks.
      _ = @store

      SaleEligibilityResult.new(blockers: blockers.uniq, warnings: warnings.uniq)
    end

    private

    def classification
      @classification ||= Catalog::ResolveClassification.call(product: @product, variant: @variant)
    end

    def available_on?(record, date)
      return false if record.available_from.present? && record.available_from > date
      return false if record.available_until.present? && record.available_until < date

      true
    end
  end
end
