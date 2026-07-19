# frozen_string_literal: true

class MerchandiseClassesController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("classification.merchandise_class.manage") }, only: %i[new create edit update]
  before_action :set_merchandise_class, only: %i[show edit update]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @merchandise_classes = Current.organization.merchandise_classes.order(:code)
  end

  def show
  end

  def new
    @merchandise_class = Current.organization.merchandise_classes.new(active: true, level: "primary")
  end

  def create
    @merchandise_class = Current.organization.merchandise_classes.new(merchandise_class_params)
    if Classification::CreateMerchandiseClass.call(
      merchandise_class: @merchandise_class,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @merchandise_class, notice: "Merchandise class created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateMerchandiseClass.call(
      merchandise_class: @merchandise_class,
      attributes: merchandise_class_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @merchandise_class, notice: "Merchandise class updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_merchandise_class
    @merchandise_class = Current.organization.merchandise_classes.find(params[:id])
  end

  def load_form_collections
    @parent_classes = MerchandiseClass.sorted_hierarchically(
      Current.organization.merchandise_classes.includes(parent: :parent)
    )
    @departments = Current.organization.departments.where(postable: true).order(:department_number)
    @tax_categories = Current.organization.tax_categories.order(:code)
  end

  def merchandise_class_params
    params.require(:merchandise_class).permit(
      :code, :name, :level, :description, :position, :parent_id,
      :default_department_id, :default_used_department_id,
      :default_inventory_tracking_mode, :default_discountability,
      :default_returnability, :default_tax_category_id, :shelving_guidance, :active
    )
  end
end
