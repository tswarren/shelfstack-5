# frozen_string_literal: true

class ProductConditionsController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("catalog.condition.manage") }, only: %i[new create edit update]
  before_action :set_product_condition, only: %i[show edit update]

  def index
    @product_conditions = Current.organization.product_conditions.order(:position, :code)
  end

  def show
  end

  def new
    @product_condition = Current.organization.product_conditions.new(active: true, position: 0)
  end

  def create
    @product_condition = Current.organization.product_conditions.new(product_condition_params)
    if Classification::CreateProductCondition.call(
      product_condition: @product_condition,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @product_condition, notice: "Product condition created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateProductCondition.call(
      product_condition: @product_condition,
      attributes: product_condition_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @product_condition, notice: "Product condition updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product_condition
    @product_condition = Current.organization.product_conditions.find(params[:id])
  end

  def product_condition_params
    params.require(:product_condition).permit(:code, :name, :description, :position, :active)
  end
end
