# frozen_string_literal: true

class ProductFormatsController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("catalog.format.manage") }, only: %i[new create edit update]
  before_action :set_product_format, only: %i[show edit update]

  def index
    @product_formats = Current.organization.product_formats.order(:code)
  end

  def show
  end

  def new
    @product_format = Current.organization.product_formats.new(active: true, default_inventory_tracking_mode: "quantity")
  end

  def create
    @product_format = Current.organization.product_formats.new(product_format_params)
    if Classification::CreateProductFormat.call(
      product_format: @product_format,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @product_format, notice: "Product format created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateProductFormat.call(
      product_format: @product_format,
      attributes: product_format_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @product_format, notice: "Product format updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product_format
    @product_format = Current.organization.product_formats.find(params[:id])
  end

  def product_format_params
    params.require(:product_format).permit(
      :code, :name, :short_code, :format_family, :default_inventory_tracking_mode, :active
    )
  end
end
