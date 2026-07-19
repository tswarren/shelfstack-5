# frozen_string_literal: true

module Catalog
  # Resolves effective merchandise class, department, and tax category for a
  # product/variant pair using the accepted inheritance chain.
  class ResolveClassification < ApplicationService
    Result = Data.define(
      :merchandise_class, :merchandise_class_source,
      :department, :department_source,
      :tax_category, :tax_category_source
    )

    def initialize(product:, variant: nil)
      @product = product
      @variant = variant || product&.product_variants&.first
    end

    def call
      mc, mc_source = resolve_merchandise_class
      dept, dept_source = resolve_department(mc)
      tax, tax_source = resolve_tax_category(mc, dept)

      Result.new(
        merchandise_class: mc, merchandise_class_source: mc_source,
        department: dept, department_source: dept_source,
        tax_category: tax, tax_category_source: tax_source
      )
    end

    private

    def resolve_merchandise_class
      if @variant&.merchandise_class
        [ @variant.merchandise_class, "Variant" ]
      elsif @product&.merchandise_class
        [ @product.merchandise_class, "Product" ]
      else
        [ nil, nil ]
      end
    end

    def resolve_department(merchandise_class)
      if @variant&.department
        [ @variant.department, "Variant" ]
      elsif @product&.default_department
        [ @product.default_department, "Product" ]
      elsif merchandise_class&.default_department
        [ merchandise_class.default_department, "Merchandise class" ]
      else
        [ nil, nil ]
      end
    end

    def resolve_tax_category(merchandise_class, department)
      if @variant&.tax_category
        [ @variant.tax_category, "Variant" ]
      elsif @product&.default_tax_category
        [ @product.default_tax_category, "Product" ]
      elsif merchandise_class&.default_tax_category
        [ merchandise_class.default_tax_category, "Merchandise class" ]
      elsif department&.default_tax_category
        [ department.default_tax_category, "Department" ]
      else
        [ nil, nil ]
      end
    end
  end
end
