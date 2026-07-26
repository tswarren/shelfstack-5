# frozen_string_literal: true

class ProductsController < ApplicationController
  before_action -> { require_permission!("catalog.product.view") }, only: %i[index show]
  before_action -> { require_permission!("catalog.product.create") }, only: %i[new create]
  before_action :set_product, only: %i[show edit update]
  before_action :require_update_permissions!, only: %i[edit update]

  def index
    @query = params[:q].to_s.strip
    scope = Current.organization.products
      .includes(:product_variants, :product_format, :merchandise_class)
      .order(:name)
    if @query.present?
      result = Catalog::Lookup.call(organization: Current.organization, query: @query)
      scope = if result.empty?
        filter_products_by_name(scope, @query)
      else
        scope.where(id: result.products.map(&:id))
      end
      @lookup_ambiguous = result.ambiguous?
    end
    @pagy, @products = pagy(:offset, scope, limit: pagy_limit)
  end

  def show
    @summary = Catalog::BuildProductSummary.call(
      product: @product,
      store: Current.store,
      actor: Current.user
    )
  end

  def new
    @product = Current.organization.products.new(
      status: "active",
      sellable: true,
      variant_structure: "single",
      product_type: "book",
      language_code: Catalog::LanguageCodes::DEFAULT
    )
    @variant = @product.product_variants.build(
      name: "Standard",
      inventory_tracking_mode: "quantity",
      sellable: true
    )
    @creator_rows = []
  end

  def create
    @product = Current.organization.products.new
    @variant = ProductVariant.new
    product_attrs = product_params.except(:creator_assignments)
    variant_attrs = variant_params

    if human_readable_params_invalid?
      prepare_create_form_redisplay!(product_attrs, variant_attrs)
      copy_human_readable_param_errors_for_product!
      render :new, status: :unprocessable_entity
      return
    end

    service = Catalog::CreateProduct.new(
      organization: Current.organization,
      actor: Current.user,
      store: Current.store,
      product_attrs: product_attrs,
      variant_attrs: variant_attrs,
      identifier: params[:identifier],
      accept_identifier_warning: ActiveModel::Type::Boolean.new.cast(params[:accept_identifier_warning]),
      accepted_identifier_normalized: params[:accepted_identifier_normalized],
      creator_assignments: creator_assignments_param
    )

    if service.call
      redirect_to service.product, notice: "Product created."
    else
      prepare_create_form_redisplay!(product_attrs, variant_attrs, service: service)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @variant = @product.product_variants.first
    @creator_rows = current_creator_rows
  end

  def update
    @variant = @product.product_variants.first
    product_attrs = product_params.except(:creator_assignments)
    variant_attrs = variant_params

    if human_readable_params_invalid?
      @product.assign_attributes(product_attrs)
      @variant.assign_attributes(variant_attrs) if @variant
      copy_human_readable_param_errors_for_product!
      @creator_rows = submitted_creator_rows
      render :edit, status: :unprocessable_entity
      return
    end

    if Catalog::UpdateProductWithStandardVariant.call(
      product: @product,
      variant: @variant,
      product_attrs: product_attrs,
      variant_attrs: variant_attrs,
      actor: Current.user,
      store: Current.store,
      creator_assignments: creator_assignments_param
    )
      redirect_to @product, notice: "Product updated."
    else
      @variant ||= @product.product_variants.build
      @creator_rows = submitted_creator_rows
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Current.organization.products.find(params[:id])
  end

  def require_update_permissions!
    require_permission!("catalog.product.edit")
    return if performed?

    if deactivating_product?
      require_permission!("catalog.product.deactivate")
      return if performed?
    end

    if variant_params_present?
      require_permission!("catalog.variant.edit")
      return if performed?
    end

    if deactivating_variant?
      require_permission!("catalog.variant.deactivate")
    end
  end

  def deactivating_product?
    return false unless params[:product] && @product

    attrs = product_params
    status = attrs[:status].presence || attrs["status"]
    if status.present? && status != "active" && @product.status == "active"
      return true
    end

    if attrs.key?(:sellable) || attrs.key?("sellable")
      new_sellable = ActiveModel::Type::Boolean.new.cast(attrs[:sellable] || attrs["sellable"])
      return true if @product.sellable? && new_sellable == false
    end

    false
  end

  def deactivating_variant?
    return false unless params[:product_variant]

    variant = @variant || @product&.product_variants&.first
    return false unless variant

    attrs = variant_params
    status = attrs[:status].presence || attrs["status"]
    if status.present? && status != "active" && variant.status == "active"
      return true
    end

    if attrs.key?(:sellable) || attrs.key?("sellable")
      new_sellable = ActiveModel::Type::Boolean.new.cast(attrs[:sellable] || attrs["sellable"])
      return true if variant.sellable? && new_sellable == false
    end

    false
  end

  def variant_params_present?
    params[:product_variant].present?
  end

  def filter_products_by_name(scope, query)
    scope.where("products.name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
  end

  def product_params
    return @product_params if defined?(@product_params)

    attrs = params.require(:product).permit(
      :name, :subtitle, :description, :product_type, :product_format_id, :merchandise_class_id,
      :default_department_id, :default_tax_category_id, :list_price_cents, :status, :sellable,
      :available_from, :available_until, :publisher_or_manufacturer_name, :imprint_or_brand_name,
      :alternate_identifier, :edition_statement, :language_code, :publication_date,
      creator_assignments: [ :creator_id, :role, :credited_as, :row_key ]
    )
    # Prices are entered as decimal dollars (`12.95`) in the UI and converted
    # to integer cents before the service contract sees them. Direct `_cents`
    # input (API/tests) still works when the decimal field is absent.
    if params[:product].key?(:list_price)
      parsed = parse_money_param(params[:product][:list_price])
      case parsed.status
      when :ok then attrs[:list_price_cents] = parsed.value
      when :blank then attrs[:list_price_cents] = nil
      when :invalid
        (@product_money_errors ||= []) << [ :list_price, parsed.error || "is not a valid amount" ]
      end
    end
    @product_params = attrs
  end

  def creator_assignments_provided?
    params[:product]&.key?(:creator_assignments_provided) || false
  end

  def creator_assignments_param
    return Catalog::ReplaceProductCreators::OMIT unless creator_assignments_provided?

    # row_key is presentation-only (DOM identity); never pass it to the service.
    Array(product_params[:creator_assignments]).map do |row|
      row.to_h.symbolize_keys.slice(:creator_id, :role, :credited_as)
    end
  end

  def current_creator_rows
    @product.product_creators.order(:position, :id).map do |product_creator|
      {
        row_key: "product_creator_#{product_creator.id}",
        creator: product_creator.creator,
        role: product_creator.role,
        credited_as: product_creator.credited_as
      }
    end
  end

  # Redisplay submitted (unpersisted) creator assignments after a validation
  # failure, resolving each id back through the current organization so a
  # foreign-organization id never discloses its label (matches the classification
  # picker redisplay pattern).
  def submitted_creator_rows
    return [] unless creator_assignments_provided?

    Array(product_params[:creator_assignments]).each_with_index.map do |row, index|
      hash = row.to_h.symbolize_keys
      creator = Catalog::ResolveRecordPickerSelection.call(
        organization: Current.organization, record_type: "creator", id: hash[:creator_id]
      )
      row_key = hash[:row_key].to_s.presence || "submitted_#{index}"
      { row_key: row_key, creator: creator, role: hash[:role], credited_as: hash[:credited_as] }
    end
  end

  def variant_params
    return @variant_params if defined?(@variant_params)

    attrs = params.require(:product_variant).permit(
      :name, :description, :inventory_tracking_mode, :default_product_condition_id,
      :regular_price_cents, :department_id, :tax_category_id, :merchandise_class_id,
      :status, :sellable, :purchasable, :available_from, :available_until
    )
    if params[:product_variant].key?(:regular_price)
      parsed = parse_money_param(params[:product_variant][:regular_price])
      case parsed.status
      when :ok then attrs[:regular_price_cents] = parsed.value
      when :blank then attrs[:regular_price_cents] = nil
      when :invalid
        (@variant_money_errors ||= []) << [ :regular_price, parsed.error || "is not a valid amount" ]
      end
    end
    @variant_params = attrs
  end

  def human_readable_params_invalid?
    @product_money_errors.present? || @variant_money_errors.present?
  end

  def copy_human_readable_param_errors_for_product!
    Array(@product_money_errors).each { |attr, message| @product.errors.add(attr, message) }
    Array(@variant_money_errors).each { |attr, message| @variant.errors.add(attr, message) }
  end

  # Rebuild the create form from submitted params so a service rollback or
  # temporary sellable:false shell cannot blank the redisplay.
  def prepare_create_form_redisplay!(product_attrs, variant_attrs, service: nil)
    @identifier = params[:identifier].to_s
    @product = Current.organization.products.new
    @product.assign_attributes(product_attrs)
    @variant = ProductVariant.new(name: variant_attrs[:name].presence || variant_attrs["name"].presence || "Standard")
    @variant.assign_attributes(variant_attrs)
    @creator_rows = submitted_creator_rows

    return unless service

    copy_errors_from!(service.product, @product) if service.product
    copy_errors_from!(service.variant, @variant) if service.variant
    @identifier_warning_normalized = service.identifier_warning_normalized
    @identifier_warning_detail = service.identifier_warning_detail

    if @product.errors.empty? && @variant.errors.empty?
      @product.errors.add(:base, "Could not create product.")
    end
  end

  def copy_errors_from!(source, target)
    source.errors.each do |error|
      target.errors.add(error.attribute, error.message)
    end
  end
end
