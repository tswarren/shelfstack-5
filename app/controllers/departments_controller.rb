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
    attrs = department_params
    @department = Current.organization.departments.new(attrs)
    copy_human_readable_param_errors!(@department)

    if @department.errors.any? || !Classification::CreateDepartment.call(
      department: @department,
      actor: Current.user,
      organization: Current.organization
    )
      render :new, status: :unprocessable_entity
    else
      redirect_to @department, notice: "Department created."
    end
  end

  def edit
  end

  def update
    attrs = department_params.to_h
    if human_readable_params_invalid?
      @department.assign_attributes(attrs)
      copy_human_readable_param_errors!(@department)
      render :edit, status: :unprocessable_entity
      return
    end

    if Classification::UpdateDepartment.call(
      department: @department,
      attributes: attrs,
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
    @parent_departments = Department.sorted_hierarchically(
      Current.organization.departments.includes(:parent_department)
    )
    @tax_categories = Current.organization.tax_categories.order(:name)
    @return_policies = Current.organization.return_policies.order(:name)
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
      write_parsed_attr!(
        attrs, :maximum_merchandise_discount,
        parse_percent_rate_param(raw[:maximum_merchandise_discount_percent])
      )
    end
    if raw.key?(:default_cost_estimation_margin_percent)
      write_parsed_attr!(
        attrs, :default_cost_estimation_margin_bps,
        parse_percent_bps_param(raw[:default_cost_estimation_margin_percent])
      )
    end

    attrs
  end
end
