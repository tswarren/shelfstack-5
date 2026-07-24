# frozen_string_literal: true

module Catalog
  # Org-scoped typeahead search for shared record pickers (Gate 8a).
  class SearchRecords < ApplicationService
    Result = Data.define(:id, :label)

    RECORD_TYPES = %w[
      merchandise_class
      department
      product_format
      tax_category
      product
      product_variant
      vendor
    ].freeze

    LIMIT = 25

    # Permission codes that authorize searching a record type. Any one match allows.
    PERMISSIONS = {
      "merchandise_class" => %w[classification.view catalog.product.view catalog.product.create catalog.product.edit],
      "department" => %w[classification.view catalog.product.view catalog.product.create catalog.product.edit],
      "product_format" => %w[classification.view catalog.product.view catalog.product.create catalog.product.edit],
      "tax_category" => %w[classification.view catalog.product.view catalog.product.create catalog.product.edit],
      "product" => %w[
        catalog.product.view catalog.product.create catalog.product.edit
        requests.product_request.view requests.product_request.create requests.product_request.edit
      ],
      "product_variant" => %w[
        catalog.product.view catalog.product.create catalog.product.edit catalog.variant.edit
        requests.product_request.view requests.product_request.create requests.product_request.edit
        purchasing.vendor_source.view purchasing.vendor_source.manage
      ],
      "vendor" => %w[
        purchasing.vendor.view purchasing.vendor.manage
        purchasing.vendor_source.view purchasing.vendor_source.manage
      ]
    }.freeze

    def initialize(organization:, record_type:, query: nil, include_inactive: false, product_id: nil, labeler: nil)
      @organization = organization
      @record_type = record_type.to_s
      @query = query.to_s.strip
      @include_inactive = include_inactive
      @product_id = product_id
      @labeler = labeler
    end

    def call
      raise ArgumentError, "unknown record type: #{@record_type}" unless RECORD_TYPES.include?(@record_type)
      raise ArgumentError, "organization required" if @organization.blank?

      records = search_records
      records.map { |record| Result.new(id: record.id, label: label_for(record)) }
    end

    def self.authorized?(user:, store:, record_type:)
      codes = PERMISSIONS[record_type.to_s]
      return false if user.blank? || codes.blank?

      codes.any? { |code| user.can?(code, store: store) }
    end

    private

    def search_records
      case @record_type
      when "merchandise_class" then search_merchandise_classes
      when "department" then search_departments
      when "product_format" then search_product_formats
      when "tax_category" then search_tax_categories
      when "product" then search_products
      when "product_variant" then search_product_variants
      when "vendor" then search_vendors
      end
    end

    def search_merchandise_classes
      scope = @organization.merchandise_classes.includes(parent: :parent)
      scope = scope.where(active: true) unless @include_inactive
      scope = apply_name_or_code_filter(scope, name_column: "merchandise_classes.name", code_column: "merchandise_classes.code")
      MerchandiseClass.sorted_hierarchically(scope.to_a).first(LIMIT)
    end

    def search_departments
      scope = @organization.departments.includes(:parent_department)
      scope = scope.where(active: true) unless @include_inactive
      scope = apply_name_or_code_filter(scope, name_column: "departments.name", code_column: "departments.code")
      Department.sorted_hierarchically(scope.to_a).first(LIMIT)
    end

    def search_product_formats
      scope = @organization.product_formats.order(:name)
      scope = scope.where(active: true) unless @include_inactive
      apply_name_or_code_filter(scope, name_column: "product_formats.name", code_column: "product_formats.code").limit(LIMIT)
    end

    def search_tax_categories
      scope = @organization.tax_categories.order(:name)
      scope = scope.where(active: true) unless @include_inactive
      apply_name_or_code_filter(scope, name_column: "tax_categories.name", code_column: "tax_categories.code").limit(LIMIT)
    end

    def search_products
      if @query.present?
        lookup = Catalog::Lookup.call(organization: @organization, query: @query)
        unless lookup.empty?
          products = lookup.products
          products = products.select { |p| p.status == "active" } unless @include_inactive
          return products.first(LIMIT) if products.any?
        end
      end

      scope = @organization.products.order(:name)
      scope = scope.where(status: "active") unless @include_inactive
      if @query.present?
        pattern = "%#{sanitize_like(@query)}%"
        scope = scope.where(
          "products.name ILIKE :q OR products.identifier ILIKE :q OR COALESCE(products.alternate_identifier, '') ILIKE :q",
          q: pattern
        )
      end
      scope.limit(LIMIT)
    end

    def search_product_variants
      scope = ProductVariant.joins(:product)
        .where(products: { organization_id: @organization.id })
        .includes(:product)
        .order("products.name", "product_variants.name")
      scope = scope.where(status: "active") unless @include_inactive
      scope = scope.where(product_id: @product_id) if @product_id.present?
      if @query.present?
        pattern = "%#{sanitize_like(@query)}%"
        scope = scope.where(
          "product_variants.name ILIKE :q OR product_variants.sku ILIKE :q OR products.name ILIKE :q",
          q: pattern
        )
      end
      scope.limit(LIMIT)
    end

    def search_vendors
      scope = @organization.vendors.order(:name)
      scope = scope.where(active: true) unless @include_inactive
      apply_name_or_code_filter(scope, name_column: "vendors.name", code_column: "vendors.code").limit(LIMIT)
    end

    def apply_name_or_code_filter(scope, name_column:, code_column:)
      return scope if @query.blank?

      pattern = "%#{sanitize_like(@query)}%"
      scope.where("#{name_column} ILIKE :q OR #{code_column} ILIKE :q", q: pattern)
    end

    def sanitize_like(value)
      ActiveRecord::Base.sanitize_sql_like(value)
    end

    def label_for(record)
      return @labeler.call(record, @record_type) if @labeler

      case @record_type
      when "merchandise_class", "department"
        path_label(record)
      when "product_variant"
        variant_label(record)
      when "product"
        name = record.name.to_s
        record.identifier.present? ? "#{name} · #{record.identifier}" : name
      when "vendor"
        [ record.name, record.code ].compact_blank.join(" — ")
      else
        name = record.name.to_s
        code = record.respond_to?(:code) ? record.code.to_s : ""
        code.present? ? "#{name} — #{code}" : name
      end
    end

    def path_label(record)
      names = []
      current = record
      seen = {}
      while current && !seen[current.id]
        seen[current.id] = true
        names.unshift(current.name)
        parent_assoc = current.class.respond_to?(:hierarchy_parent_association) ?
          current.class.hierarchy_parent_association : :parent
        current = current.respond_to?(parent_assoc) ? current.public_send(parent_assoc) : nil
      end
      path = names.join(" › ")
      if record.respond_to?(:department_number) && record.department_number.present?
        "#{path} · #{record.department_number}"
      else
        path
      end
    end

    def variant_label(record)
      product_name = record.product&.name.presence || "Product"
      variant_name = record.name.presence || "Standard"
      "#{product_name} — #{variant_name} · SKU #{record.sku}"
    end
  end
end
