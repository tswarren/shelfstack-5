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
    @pagy, @products = pagy(scope, limit: pagy_limit)
  end

  def show
    @variants = @product.product_variants.order(:name)
    @stock_balances = Current.store.stock_balances
      .where(product_variant_id: @variants.map(&:id))
      .index_by(&:product_variant_id)
  end

  def new
    @product = Current.organization.products.new(
      status: "active",
      sellable: false,
      variant_structure: "single",
      product_type: "book"
    )
    @variant = @product.product_variants.build(
      name: "Standard",
      inventory_tracking_mode: "quantity",
      sellable: true
    )
  end

  def create
    @product = Current.organization.products.new
    @variant = ProductVariant.new

    service = Catalog::CreateProduct.new(
      organization: Current.organization,
      actor: Current.user,
      store: Current.store,
      product_attrs: product_params,
      variant_attrs: variant_params,
      identifier: params[:identifier],
      accept_identifier_warning: ActiveModel::Type::Boolean.new.cast(params[:accept_identifier_warning])
    )

    if service.call
      redirect_to service.product, notice: "Product created."
    else
      @product = service.product || Current.organization.products.new(product_params)
      @variant = service.variant || ProductVariant.new(variant_params)
      if @product.errors.empty? && @variant.errors.empty?
        @product.errors.add(:base, "Could not create product.")
      end
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @variant = @product.product_variants.first
  end

  def update
    @variant = @product.product_variants.first

    if Catalog::UpdateProductWithStandardVariant.call(
      product: @product,
      variant: @variant,
      product_attrs: product_params,
      variant_attrs: variant_params,
      actor: Current.user,
      store: Current.store
    )
      redirect_to @product, notice: "Product updated."
    else
      @variant ||= @product.product_variants.build
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
    attrs = params.require(:product).permit(
      :name, :subtitle, :description, :product_type, :product_format_id, :merchandise_class_id,
      :default_department_id, :default_tax_category_id, :list_price_cents, :status, :sellable,
      :available_from, :available_until, :publisher_or_manufacturer_name, :imprint_or_brand_name,
      :alternate_identifier
    )
    # Prices are entered as decimal dollars (`12.95`) in the UI and converted
    # to integer cents before the service contract sees them. Direct `_cents`
    # input (API/tests) still works when the decimal field is absent.
    if params[:product].key?(:list_price)
      attrs[:list_price_cents] = helpers.parse_money_to_cents(params[:product][:list_price])
    end
    attrs
  end

  def variant_params
    attrs = params.require(:product_variant).permit(
      :name, :description, :inventory_tracking_mode, :default_product_condition_id,
      :regular_price_cents, :department_id, :tax_category_id, :merchandise_class_id,
      :status, :sellable, :purchasable, :available_from, :available_until
    )
    if params[:product_variant].key?(:regular_price)
      attrs[:regular_price_cents] = helpers.parse_money_to_cents(params[:product_variant][:regular_price])
    end
    attrs
  end
end
