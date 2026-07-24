# frozen_string_literal: true

module Catalog
  # Resolve a record-picker selection only when it belongs to the current organization.
  # Prevents validation-rerender disclosure of foreign-organization labels.
  class ResolveRecordPickerSelection < ApplicationService
    def initialize(organization:, record_type:, id:)
      @organization = organization
      @record_type = record_type.to_s
      @id = id
    end

    def call
      return nil if @organization.blank? || @id.blank?
      raise ArgumentError, "unknown record type: #{@record_type}" unless SearchRecords::RECORD_TYPES.include?(@record_type)

      case @record_type
      when "merchandise_class"
        @organization.merchandise_classes.find_by(id: @id)
      when "department"
        @organization.departments.find_by(id: @id)
      when "product_format"
        @organization.product_formats.find_by(id: @id)
      when "tax_category"
        @organization.tax_categories.find_by(id: @id)
      when "product"
        @organization.products.find_by(id: @id)
      when "product_variant"
        ProductVariant.joins(:product)
          .where(products: { organization_id: @organization.id })
          .find_by(product_variants: { id: @id })
      when "vendor"
        @organization.vendors.find_by(id: @id)
      when "creator"
        # No active filter: inactive Creators already linked to a Product
        # must remain visible on that Product's form (phase-08 §5).
        @organization.creators.find_by(id: @id)
      end
    end
  end
end
