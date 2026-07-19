# frozen_string_literal: true

class DiscountReasonsController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index show]
  before_action -> { require_permission!("classification.reason.manage") }, only: %i[new create edit update]
  before_action :set_discount_reason, only: %i[show edit update]

  def index
    @discount_reasons = Current.organization.discount_reasons.order(:code)
  end

  def show
  end

  def new
    @discount_reason = Current.organization.discount_reasons.new(active: true, requires_approval: true)
    @return_policies = Current.organization.return_policies.order(:code)
  end

  def create
    @discount_reason = Current.organization.discount_reasons.new(discount_reason_params)
    @return_policies = Current.organization.return_policies.order(:code)
    if Classification::CreateDiscountReason.call(
      discount_reason: @discount_reason,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @discount_reason, notice: "Discount reason created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @return_policies = Current.organization.return_policies.order(:code)
  end

  def update
    @return_policies = Current.organization.return_policies.order(:code)
    if Classification::UpdateDiscountReason.call(
      discount_reason: @discount_reason,
      attributes: discount_reason_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @discount_reason, notice: "Discount reason updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_discount_reason
    @discount_reason = Current.organization.discount_reasons.find(params[:id])
  end

  def discount_reason_params
    attrs = params.require(:discount_reason).permit(
      :code, :name, :default_calculation_method, :default_rate_bps, :default_amount_cents,
      :maximum_rate_bps, :requires_approval, :resulting_return_policy_id, :active
    )

    # Rates are entered as percentages and the amount as decimal dollars in the UI,
    # then converted to basis points / integer cents. Direct column input
    # (API/tests) still works when the human-readable field is absent.
    raw = params[:discount_reason] || {}
    attrs[:default_rate_bps] = helpers.parse_percent_to_bps(raw[:default_rate_percent]) if raw.key?(:default_rate_percent)
    attrs[:maximum_rate_bps] = helpers.parse_percent_to_bps(raw[:maximum_rate_percent]) if raw.key?(:maximum_rate_percent)
    attrs[:default_amount_cents] = helpers.parse_money_to_cents(raw[:default_amount]) if raw.key?(:default_amount)

    attrs
  end
end
