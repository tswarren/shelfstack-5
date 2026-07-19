# frozen_string_literal: true

class DepartmentsController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("classification.department.manage") }, only: %i[new create edit update]
  before_action :set_department, only: %i[show edit update]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @departments = Current.organization.departments.order(:department_number)
  end

  def show
  end

  def new
    @department = Current.organization.departments.new(active: true, postable: true)
  end

  def create
    @department = Current.organization.departments.new(department_params)
    if Classification::CreateDepartment.call(
      department: @department,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @department, notice: "Department created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateDepartment.call(
      department: @department,
      attributes: department_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @department, notice: "Department updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_department
    @department = Current.organization.departments.find(params[:id])
  end

  def load_form_collections
    @parent_departments = Current.organization.departments.order(:department_number)
    @tax_categories = Current.organization.tax_categories.order(:code)
    @return_policies = Current.organization.return_policies.order(:code)
  end

  def department_params
    attrs = params.require(:department).permit(
      :code, :department_number, :name, :parent_department_id, :postable,
      :inventory_asset_gl_account_code, :sales_revenue_gl_account_code,
      :sales_returns_gl_account_code, :sales_discounts_gl_account_code,
      :cogs_gl_account_code, :vendor_returns_gl_account_code,
      :inventory_shrinkage_gl_account_code, :inventory_write_down_gl_account_code,
      :inventory_adjustment_gl_account_code, :freight_in_gl_account_code,
      :default_tax_category_id, :maximum_merchandise_discount, :default_return_policy_id,
      :default_cost_estimation_margin_bps, :active
    )

    # The maximum discount and margin are entered as percentages in the UI and
    # converted to the domain's decimal-rate / basis-point storage. Direct column
    # input (API/tests) still works when the percent field is absent.
    raw = params[:department] || {}
    if raw.key?(:maximum_merchandise_discount_percent)
      attrs[:maximum_merchandise_discount] = helpers.parse_percent_to_rate(raw[:maximum_merchandise_discount_percent])
    end
    if raw.key?(:default_cost_estimation_margin_percent)
      attrs[:default_cost_estimation_margin_bps] = helpers.parse_percent_to_bps(raw[:default_cost_estimation_margin_percent])
    end

    attrs
  end
end
