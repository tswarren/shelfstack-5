# frozen_string_literal: true

class ReturnPoliciesController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("classification.return_policy.manage") }, only: %i[new create edit update]
  before_action :set_return_policy, only: %i[show edit update]

  def index
    @return_policies = Current.organization.return_policies.order(:code)
  end

  def show
  end

  def new
    @return_policy = Current.organization.return_policies.new(active: true, final_sale: false)
  end

  def create
    @return_policy = Current.organization.return_policies.new(return_policy_params)
    if Classification::CreateReturnPolicy.call(
      return_policy: @return_policy,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @return_policy, notice: "Return policy created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateReturnPolicy.call(
      return_policy: @return_policy,
      attributes: return_policy_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @return_policy, notice: "Return policy updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_return_policy
    @return_policy = Current.organization.return_policies.find(params[:id])
  end

  def return_policy_params
    params.require(:return_policy).permit(:code, :name, :final_sale, :return_window_days, :active)
  end
end
