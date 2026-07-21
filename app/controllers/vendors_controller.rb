# frozen_string_literal: true

class VendorsController < ApplicationController
  before_action -> { require_permission!("purchasing.vendor.view") }, only: %i[index show]
  before_action -> { require_permission!("purchasing.vendor.manage") }, only: %i[new create edit update]
  before_action :set_vendor, only: %i[show edit update]

  def index
    @vendors = Current.organization.vendors.order(:code)
  end

  def show
    @product_variant_vendors = @vendor.product_variant_vendors.includes(product_variant: :product).order(:id)
    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store)
    @can_manage_sources = Current.user.can?("purchasing.vendor_source.manage", store: Current.store)
  end

  def new
    @vendor = Current.organization.vendors.new(active: true)
  end

  def create
    @vendor = Current.organization.vendors.new(vendor_params)

    if Purchasing::CreateVendor.call(
      vendor: @vendor,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @vendor, notice: "Vendor created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Purchasing::UpdateVendor.call(
      vendor: @vendor,
      attributes: vendor_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @vendor, notice: "Vendor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_vendor
    @vendor = Current.organization.vendors.find(params[:id])
  end

  def vendor_params
    params.require(:vendor).permit(
      :code, :name, :legal_name, :active, :ordering_contact, :ordering_email,
      :phone, :account_reference, :default_supplier_discount_bps, :notes
    )
  end
end
