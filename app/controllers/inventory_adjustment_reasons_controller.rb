# frozen_string_literal: true

class InventoryAdjustmentReasonsController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("classification.reason.manage") }, only: %i[new create edit update]
  before_action :set_reason, only: %i[show edit update]

  def index
    @inventory_adjustment_reasons = Current.organization.inventory_adjustment_reasons.ordered
  end

  def show
  end

  def new
    @inventory_adjustment_reason = Current.organization.inventory_adjustment_reasons.new(
      active: true,
      requires_note: false,
      position: 0
    )
  end

  def create
    @inventory_adjustment_reason = Current.organization.inventory_adjustment_reasons.new(reason_params)
    if Classification::CreateInventoryAdjustmentReason.call(
      inventory_adjustment_reason: @inventory_adjustment_reason,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @inventory_adjustment_reason, notice: "Inventory adjustment reason created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateInventoryAdjustmentReason.call(
      inventory_adjustment_reason: @inventory_adjustment_reason,
      attributes: reason_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @inventory_adjustment_reason, notice: "Inventory adjustment reason updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_reason
    @inventory_adjustment_reason = Current.organization.inventory_adjustment_reasons.find(params[:id])
  end

  def reason_params
    params.require(:inventory_adjustment_reason).permit(
      :adjustment_kind, :code, :name, :description, :requires_note, :active, :position
    )
  end
end
