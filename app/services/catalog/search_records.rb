# frozen_string_literal: true

module Catalog
  # Org-scoped typeahead search for shared record pickers (Gate 8a).
  class SearchRecords < ApplicationService
    Result = Data.define(:id, :label, :status, :inactive)

    RECORD_TYPES = %w[
      merchandise_class
      department
      product_format
      tax_category
      product
      product_variant
      vendor
      creator
      customer
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
      ],
      "creator" => %w[
        catalog.product.view catalog.product.create catalog.product.edit catalog.manage_creators
      ],
      # Full view or narrower lookup — not pos.access / request edit alone.
      "customer" => %w[customers.customer.view customers.customer.lookup]
    }.freeze

    def initialize(organization:, record_type:, query: nil, include_inactive: false, product_id: nil, labeler: nil, default_phone_country: nil)
      @organization = organization
      @record_type = record_type.to_s
      @query = query.to_s.strip
      @include_inactive = include_inactive
      @product_id = product_id
      @labeler = labeler
      @default_phone_country = default_phone_country
    end

    def call
      raise ArgumentError, "unknown record type: #{@record_type}" unless RECORD_TYPES.include?(@record_type)
      raise ArgumentError, "organization required" if @organization.blank?

      search_records.map { |record| build_result(record) }
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
      when "creator" then search_creators
      when "customer" then search_customers
      end
    end

    def search_merchandise_classes
      scope = @organization.merchandise_classes.includes(parent: :parent)
      scope = scope.where(active: true) unless @include_inactive
      scope = apply_name_or_code_filter(scope)
      MerchandiseClass.sorted_hierarchically(scope.to_a).first(LIMIT)
    end

    def search_departments
      scope = @organization.departments.includes(:parent_department)
      scope = scope.where(active: true) unless @include_inactive
      scope = apply_name_or_code_filter(scope)
      Department.sorted_hierarchically(scope.to_a).first(LIMIT)
    end

    def search_product_formats
      scope = @organization.product_formats.order(:name)
      scope = scope.where(active: true) unless @include_inactive
      apply_name_or_code_filter(scope).limit(LIMIT)
    end

    def search_tax_categories
      scope = @organization.tax_categories.order(:name)
      scope = scope.where(active: true) unless @include_inactive
      apply_name_or_code_filter(scope).limit(LIMIT)
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
      scope = base_variant_scope
      if @query.present?
        lookup_variants = variants_from_product_lookup
        return lookup_variants if lookup_variants.any?

        pattern = "%#{sanitize_like(@query)}%"
        scope = scope.where(
          "product_variants.name ILIKE :q OR product_variants.sku ILIKE :q OR products.name ILIKE :q " \
          "OR products.identifier ILIKE :q OR COALESCE(products.alternate_identifier, '') ILIKE :q",
          q: pattern
        )
      end
      scope.limit(LIMIT)
    end

    def base_variant_scope
      scope = ProductVariant.joins(:product)
        .where(products: { organization_id: @organization.id })
        .includes(:product)
        .order("products.name", "product_variants.name")
      unless @include_inactive
        scope = scope.where(status: "active").where(products: { status: "active" })
      end
      scope = scope.where(product_id: @product_id) if @product_id.present?
      scope
    end

    def variants_from_product_lookup
      lookup = Catalog::Lookup.call(organization: @organization, query: @query)
      return [] if lookup.empty?

      product_ids = lookup.products.map(&:id)
      product_ids &= [ @product_id.to_i ] if @product_id.present?
      return [] if product_ids.empty?

      base_variant_scope.where(product_id: product_ids).limit(LIMIT).to_a
    end

    def search_vendors
      scope = @organization.vendors.order(:name)
      scope = scope.where(active: true) unless @include_inactive
      apply_name_or_code_filter(scope).limit(LIMIT)
    end

    def search_creators
      scope = @organization.creators.order(:sort_name)
      scope = scope.where(active: true) unless @include_inactive
      if @query.present?
        pattern = "%#{sanitize_like(@query)}%"
        scope = scope.where(
          "display_name ILIKE :q OR sort_name ILIKE :q OR normalized_name ILIKE :q",
          q: pattern
        )
      end
      scope.limit(LIMIT)
    end

    # Delegates typed search to Customers::Search (Customers domain). Blank query
    # returns a bounded active list for picker open. Caller-controlled
    # include_inactive is ignored — inactive appears only via direct number match.
    def search_customers
      if @query.present?
        result = Customers::Search.call(
          organization: @organization,
          query: @query,
          include_inactive: false,
          default_phone_country: @default_phone_country,
          limit: LIMIT
        )
        customers = result.customers.select { |c| c.active? || result.inactive_direct_match&.id == c.id }
        return customers.first(LIMIT)
      end

      @organization.customers.active.order(:last_name, :first_name, :organization_name).limit(LIMIT)
    end

    def apply_name_or_code_filter(scope)
      return scope if @query.blank?

      pattern = "%#{sanitize_like(@query)}%"
      table = scope.klass.arel_table
      scope.where(
        table[:name].matches(pattern, nil, false)
          .or(table[:code].matches(pattern, nil, false))
      )
    end

    def sanitize_like(value)
      ActiveRecord::Base.sanitize_sql_like(value)
    end

    def build_result(record)
      status = status_for(record)
      inactive = inactive?(record, status)
      base_label = @labeler ? @labeler.call(record, @record_type) : label_for(record)
      label = inactive && @include_inactive ? "#{base_label} · #{status_suffix(status)}" : base_label
      Result.new(id: record.id, label: label, status: status, inactive: inactive)
    end

    def status_for(record)
      case @record_type
      when "product_variant"
        product_status = record.product&.status.to_s
        return product_status if product_status.present? && product_status != "active"
        record.status.to_s
      when "product"
        record.status.to_s
      else
        if record.respond_to?(:active)
          record.active? ? "active" : "inactive"
        else
          "active"
        end
      end
    end

    def inactive?(record, status)
      case @record_type
      when "product", "product_variant"
        status != "active"
      else
        record.respond_to?(:active) ? !record.active? : false
      end
    end

    def status_suffix(status)
      case status.to_s
      when "discontinued" then "Discontinued"
      when "inactive" then "Inactive"
      else status.to_s.titleize.presence || "Inactive"
      end
    end

    def label_for(record)
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
      when "creator"
        creator_label(record)
      when "customer"
        customer_label(record)
      else
        name = record.name.to_s
        code = record.respond_to?(:code) ? record.code.to_s : ""
        code.present? ? "#{name} — #{code}" : name
      end
    end

    def customer_label(record)
      record.picker_label(query: @query)
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

    # Duplicate display names are acceptable in v1 (OD-P8-02); always pair a
    # stable disambiguator so the picker never shows two indistinguishable rows.
    def creator_label(record)
      if record.sort_name.present? && record.sort_name != record.display_name
        "#{record.display_name} — #{record.sort_name}"
      else
        "#{record.display_name} — Creator #{record.id}"
      end
    end
  end
end
