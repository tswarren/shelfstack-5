# frozen_string_literal: true

class ReturnReasonsController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("classification.reason.manage") }, only: %i[new create edit update]
  before_action :set_return_reason, only: %i[show edit update]

  def index
    @return_reasons = Current.organization.return_reasons.order(:code)
  end

  def show
  end

  def new
    @return_reason = Current.organization.return_reasons.new(active: true)
  end

  def create
    @return_reason = Current.organization.return_reasons.new(return_reason_params)
    if Classification::CreateReturnReason.call(
      return_reason: @return_reason,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @return_reason, notice: "Return reason created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateReturnReason.call(
      return_reason: @return_reason,
      attributes: return_reason_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @return_reason, notice: "Return reason updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_return_reason
    @return_reason = Current.organization.return_reasons.find(params[:id])
  end

  def return_reason_params
    params.require(:return_reason).permit(:code, :name, :default_return_disposition, :active)
  end
end
