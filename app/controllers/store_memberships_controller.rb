# frozen_string_literal: true

class StoreMembershipsController < ApplicationController
  before_action -> { require_permission!("administration.membership.manage") }
  before_action :set_membership, only: %i[edit update]

  def index
    @memberships = Current.store.store_memberships.includes(:user, :role).joins(:user).order("users.username")
  end

  def new
    @membership = Current.store.store_memberships.new
    # Installation-global user list (INV-ORG-001); access is granted by membership.
    @users = User.order(:username)
    @roles = Current.organization.roles.order(:code)
  end

  def create
    attrs = membership_params
    @membership = Current.store.store_memberships.new(attrs)
    @membership.assigned_by_user = Current.user
    copy_human_readable_param_errors!(@membership)

    if @membership.errors.any? || !Administration::CreateStoreMembership.call(
      membership: @membership,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      @users = User.order(:username)
      @roles = Current.organization.roles.order(:code)
      render :new, status: :unprocessable_entity
    else
      redirect_to store_memberships_path, notice: "Membership created."
    end
  end

  def edit
    @roles = Current.organization.roles.order(:code)
  end

  def update
    attrs = membership_update_params.to_h
    if human_readable_params_invalid?
      copy_human_readable_param_errors!(@membership)
      @roles = Current.organization.roles.order(:code)
      render :edit, status: :unprocessable_entity
      return
    end

    if Administration::UpdateStoreMembership.call(
      membership: @membership,
      attributes: attrs,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to store_memberships_path, notice: "Membership updated."
    else
      @roles = Current.organization.roles.order(:code)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_membership
    @membership = Current.store.store_memberships.find(params[:id])
  end

  def membership_params
    attrs = params.require(:store_membership).permit(
      :user_id, :role_id, :active, :starts_on, :ends_on,
      :maximum_discount_rate, :maximum_discount_amount_cents,
      :maximum_price_override_rate, :maximum_cash_refund_cents,
      :maximum_no_receipt_return_cents, :maximum_paid_out_cents,
      :cash_variance_review_threshold_cents
    )
    apply_human_readable_authority(attrs)
  end

  def membership_update_params
    attrs = params.require(:store_membership).permit(
      :role_id, :active, :starts_on, :ends_on,
      :maximum_discount_rate, :maximum_discount_amount_cents,
      :maximum_price_override_rate, :maximum_cash_refund_cents,
      :maximum_no_receipt_return_cents, :maximum_paid_out_cents,
      :cash_variance_review_threshold_cents
    )
    apply_human_readable_authority(attrs)
  end

  # Rates are entered as percentages and money as decimal dollars in the UI, then
  # converted to the domain's decimal-rate / integer-cents storage. Direct column
  # input (API/tests) still works when the human-readable field is absent.
  def apply_human_readable_authority(attrs)
    raw = params[:store_membership] || {}

    {
      maximum_discount_rate_percent: :maximum_discount_rate,
      maximum_price_override_rate_percent: :maximum_price_override_rate
    }.each do |input_key, column|
      next unless raw.key?(input_key)

      write_parsed_attr!(attrs, column, parse_percent_rate_param(raw[input_key]))
    end

    {
      maximum_discount_amount: :maximum_discount_amount_cents,
      maximum_cash_refund: :maximum_cash_refund_cents,
      maximum_no_receipt_return: :maximum_no_receipt_return_cents,
      maximum_paid_out: :maximum_paid_out_cents,
      cash_variance_review_threshold: :cash_variance_review_threshold_cents
    }.each do |input_key, column|
      next unless raw.key?(input_key)

      write_parsed_attr!(attrs, column, parse_money_param(raw[input_key]))
    end

    attrs
  end
end
