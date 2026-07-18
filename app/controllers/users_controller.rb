# frozen_string_literal: true

class UsersController < ApplicationController
  before_action -> { require_permission!("administration.user.view") }, only: %i[index show]
  before_action -> { require_permission!("administration.user.manage") }, only: %i[new create edit update]
  before_action :set_user, only: %i[show edit update]

  def index
    @users = organization_users.order(:username)
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      audit!("user.created", @user)
      redirect_to @user, notice: "User created. Assign a store membership to grant access."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = user_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?
    if @user.update(attrs)
      audit!("user.updated", @user)
      redirect_to @user, notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organization_users
    store_ids = Current.organization.stores.select(:id)
    User.left_joins(:store_memberships).where(
      "store_memberships.store_id IN (?) OR users.id = ?",
      store_ids,
      Current.user.id
    ).distinct
  end

  def set_user
    @user = if action_name == "show" && !Current.user.can?("administration.user.manage", store: Current.store)
      organization_users.find(params[:id])
    else
      User.find(params[:id])
    end
  end

  def user_params
    params.require(:user).permit(
      :username, :user_number, :first_name, :last_name, :email,
      :password, :password_confirmation, :default_store_id, :active
    )
  end

  def audit!(action, user)
    Administration::RecordAuditEvent.call(
      actor: Current.user,
      organization: Current.organization,
      store: Current.store,
      action: action,
      subject: user,
      metadata: { username: user.username }
    )
  end
end
