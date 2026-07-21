# frozen_string_literal: true

class ProductVariantVendorsController < ApplicationController
  before_action -> { require_permission!("purchasing.vendor_source.view") }, only: %i[index show]
  before_action -> { require_permission!("purchasing.vendor_source.manage") }, only: %i[new create edit update]
  before_action :set_product_variant_vendor, only: %i[show edit update]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @product_variant_vendors = ProductVariantVendor
      .joins(:vendor)
      .where(vendors: { organization_id: Current.organization.id })
      .includes(:vendor, product_variant: :product)
      .order("vendors.code", :id)
    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store)
  end

  def show
    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store)
  end

  def new
    @product_variant_vendor = ProductVariantVendor.new(active: true, preferred: false)
    @product_variant_vendor.vendor_id = params[:vendor_id] if params[:vendor_id].present?
    @product_variant_vendor.product_variant_id = params[:product_variant_id] if params[:product_variant_id].present?
  end

  def create
    @product_variant_vendor = ProductVariantVendor.new(product_variant_vendor_params)

    if Purchasing::CreateProductVariantVendor.call(
      product_variant_vendor: @product_variant_vendor,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @product_variant_vendor, notice: "Vendor source created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Purchasing::UpdateProductVariantVendor.call(
      product_variant_vendor: @product_variant_vendor,
      attributes: product_variant_vendor_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @product_variant_vendor, notice: "Vendor source updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product_variant_vendor
    @product_variant_vendor = ProductVariantVendor
      .joins(:vendor)
      .where(vendors: { organization_id: Current.organization.id })
      .find(params[:id])
  end

  def load_form_collections
    @vendors = Current.organization.vendors.where(active: true).order(:code)
    @product_variants = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id })
      .includes(:product)
      .order("products.name", :name)
  end

  def product_variant_vendor_params
    params.require(:product_variant_vendor).permit(
      :product_variant_id, :vendor_id, :vendor_item_code, :vendor_identifier,
      :list_cost_cents, :discount_bps, :expected_unit_cost_cents,
      :minimum_order_quantity, :order_multiple, :returnable, :preferred, :active, :notes
    )
  end
end
