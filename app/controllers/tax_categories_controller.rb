# frozen_string_literal: true

class TaxCategoriesController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("classification.tax_category.manage") }, only: %i[new create edit update]
  before_action :set_tax_category, only: %i[show edit update]

  def index
    @tax_categories = Current.organization.tax_categories.order(:code)
  end

  def show
  end

  def new
    @tax_category = Current.organization.tax_categories.new(active: true)
  end

  def create
    @tax_category = Current.organization.tax_categories.new(tax_category_params)
    if Classification::CreateTaxCategory.call(
      tax_category: @tax_category,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @tax_category, notice: "Tax category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateTaxCategory.call(
      tax_category: @tax_category,
      attributes: tax_category_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @tax_category, notice: "Tax category updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_tax_category
    @tax_category = Current.organization.tax_categories.find(params[:id])
  end

  def tax_category_params
    params.require(:tax_category).permit(:code, :name, :active)
  end
end
