# frozen_string_literal: true

class ProductsController < ApplicationController
  before_action -> { require_permission!("catalog.product.view") }, only: %i[index show]
  before_action -> { require_permission!("catalog.product.create") }, only: %i[new create]
  before_action -> { require_permission!("catalog.product.edit") }, only: %i[edit update]
  before_action :set_product, only: %i[show edit update]

  def index
    @query = params[:q].to_s.strip
    @products = Current.organization.products.includes(:product_variants).order(:name)
    @products = filter_products(@products, @query) if @query.present?
  end

  def show
    @variants = @product.product_variants.order(:name)
  end

  def new
    @product = Current.organization.products.new(status: "active", sellable: true, variant_structure: "single")
    @variant = @product.product_variants.build(name: "Standard", inventory_tracking_mode: "quantity", sellable: true)
  end

  def create
    @product = Current.organization.products.new
    @variant = @product.product_variants.build

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
      @variant = service.variant || @product.product_variants.build(variant_params)
      @product.errors.add(:base, "Could not create product.") if @product.errors.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @variant = @product.product_variants.first
  end

  def update
    product_updated = Catalog::UpdateProduct.call(
      product: @product,
      attributes: product_params,
      actor: Current.user,
      store: Current.store
    )

    variant = @product.product_variants.first
    variant_updated = variant.nil? || Catalog::UpdateVariant.call(
      variant: variant,
      attributes: variant_params,
      actor: Current.user,
      store: Current.store
    )

    if product_updated && variant_updated
      redirect_to @product, notice: "Product updated."
    else
      @variant = variant || @product.product_variants.build
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Current.organization.products.find(params[:id])
  end

  def filter_products(scope, query)
    normalized = Identifiers::Normalize.call(query)
    canonical = normalized.canonical.presence

    if canonical.present?
      by_identifier = scope.where(identifier: canonical)
      return by_identifier if by_identifier.exists?

      by_sku = scope.joins(:product_variants).where(product_variants: { sku: canonical })
      return by_sku if by_sku.exists?
    end

    scope.where("products.name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
  end

  def product_params
    params.require(:product).permit(
      :name, :subtitle, :description, :product_type, :product_format_id, :merchandise_class_id,
      :default_department_id, :default_tax_category_id, :list_price_cents, :status, :sellable,
      :available_from, :available_until, :publisher_or_manufacturer_name, :imprint_or_brand_name,
      :alternate_identifier
    )
  end

  def variant_params
    params.require(:product_variant).permit(
      :name, :description, :inventory_tracking_mode, :default_product_condition_id,
      :regular_price_cents, :department_id, :tax_category_id, :merchandise_class_id,
      :status, :sellable, :purchasable, :available_from, :available_until
    )
  end
end
