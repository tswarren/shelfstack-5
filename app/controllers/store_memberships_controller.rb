# frozen_string_literal: true

class StoreMembershipsController < ApplicationController
  before_action -> { require_permission!("administration.membership.manage") }
  before_action :set_membership, only: %i[edit update]

  def index
    @memberships = Current.store.store_memberships.includes(:user, :role).joins(:user).order("users.username")
  end

  def new
    @membership = Current.store.store_memberships.new
    @users = User.order(:username)
    @roles = Current.organization.roles.order(:code)
  end

  def create
    @membership = Current.store.store_memberships.new(membership_params)
    @membership.assigned_by_user = Current.user
    if @membership.save
      audit!("membership.created", @membership)
      redirect_to store_memberships_path, notice: "Membership created."
    else
      @users = User.order(:username)
      @roles = Current.organization.roles.order(:code)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.order(:username)
    @roles = Current.organization.roles.order(:code)
  end

  def update
    if @membership.update(membership_params)
      audit!("membership.updated", @membership)
      redirect_to store_memberships_path, notice: "Membership updated."
    else
      @users = User.order(:username)
      @roles = Current.organization.roles.order(:code)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_membership
    @membership = Current.store.store_memberships.find(params[:id])
  end

  def membership_params
    params.require(:store_membership).permit(
      :user_id, :role_id, :active, :starts_on, :ends_on,
      :maximum_discount_rate, :maximum_discount_amount_cents,
      :maximum_price_override_rate, :maximum_cash_refund_cents,
      :maximum_no_receipt_return_cents, :maximum_paid_out_cents,
      :cash_variance_review_threshold_cents
    )
  end

  def audit!(action, membership)
    Administration::RecordAuditEvent.call(
      actor: Current.user,
      organization: Current.organization,
      store: Current.store,
      action: action,
      subject: membership,
      metadata: { user_id: membership.user_id, role_id: membership.role_id }
    )
  end
end
