# frozen_string_literal: true

module Catalog
  # Hub-facing effective / configured values for the Product summary (Gate 8d).
  # Classification delegates to ResolveClassification; source labels are mapped
  # for staff display only. Tracking/return/discount settings are configured
  # Variant fields, not inherited classification results.
  class ResolveEffectiveValues < ApplicationService
    ResolvedValue = Data.define(:value, :source_label)

    Result = Data.define(
      :merchandise_class,
      :department,
      :tax_category,
      :tracking_mode,
      :returnability_setting,
      :discountability_setting,
      :return_policy
    )

    SOURCE_LABELS = {
      "Variant" => "Item override",
      "Product" => "Product override",
      "Merchandise class" => "Merchandise-class default",
      "Department" => "Department default"
    }.freeze

    def initialize(product:, variant:)
      @product = product
      @variant = variant
    end

    def call
      raise ArgumentError, "variant is required" if @variant.nil?

      classification = Catalog::ResolveClassification.call(product: @product, variant: @variant)

      Result.new(
        merchandise_class: classified(classification.merchandise_class, classification.merchandise_class_source),
        department: classified(classification.department, classification.department_source),
        tax_category: classified(classification.tax_category, classification.tax_category_source),
        tracking_mode: configured(@variant.inventory_tracking_mode),
        returnability_setting: configured(@variant.returnability_setting),
        discountability_setting: configured(@variant.discountability_setting),
        return_policy: configured(@variant.return_policy)
      )
    end

    private

    def classified(value, resolver_source)
      if value.nil? && resolver_source.blank?
        ResolvedValue.new(value: nil, source_label: "Missing")
      else
        ResolvedValue.new(value: value, source_label: SOURCE_LABELS.fetch(resolver_source, "Missing"))
      end
    end

    # Boolean false and string "default" are real configured values.
    def configured(value)
      if value.nil? || (value.is_a?(String) && value.strip.empty?)
        ResolvedValue.new(value: nil, source_label: "Missing")
      else
        ResolvedValue.new(value: value, source_label: "Standard item")
      end
    end
  end
end
