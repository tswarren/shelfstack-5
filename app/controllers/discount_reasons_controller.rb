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
    attrs = discount_reason_params
    @discount_reason = Current.organization.discount_reasons.new(attrs)
    @return_policies = Current.organization.return_policies.order(:code)
    copy_human_readable_param_errors!(@discount_reason)

    if @discount_reason.errors.any? || !Classification::CreateDiscountReason.call(
      discount_reason: @discount_reason,
      actor: Current.user,
      organization: Current.organization
    )
      render :new, status: :unprocessable_entity
    else
      redirect_to @discount_reason, notice: "Discount reason created."
    end
  end

  def edit
    @return_policies = Current.organization.return_policies.order(:code)
  end

  def update
    @return_policies = Current.organization.return_policies.order(:code)
    attrs = discount_reason_params.to_h
    if human_readable_params_invalid?
      copy_human_readable_param_errors!(@discount_reason)
      render :edit, status: :unprocessable_entity
      return
    end

    if Classification::UpdateDiscountReason.call(
      discount_reason: @discount_reason,
      attributes: attrs,
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
    if raw.key?(:default_rate_percent)
      write_parsed_attr!(
        attrs, :default_rate_bps, parse_percent_bps_param(raw[:default_rate_percent]),
        presentation_attr: :default_rate_bps
      )
    end
    if raw.key?(:maximum_rate_percent)
      write_parsed_attr!(
        attrs, :maximum_rate_bps, parse_percent_bps_param(raw[:maximum_rate_percent]),
        presentation_attr: :maximum_rate_bps
      )
    end
    if raw.key?(:default_amount)
      write_parsed_attr!(
        attrs, :default_amount_cents, parse_money_param(raw[:default_amount]),
        presentation_attr: :default_amount_cents
      )
    end

    attrs
  end
end
