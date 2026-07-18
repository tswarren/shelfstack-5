# frozen_string_literal: true

class UsersController < ApplicationController
  before_action -> { require_permission!("administration.user.view") }, only: %i[index show]
  before_action -> { require_permission!("administration.user.manage") }, only: %i[new create edit update]
  before_action :set_user, only: %i[show edit update]

  def index
    # Users are installation-global under INV-ORG-001 (one organization per install).
    @users = User.order(:username)
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if Administration::CreateUser.call(
      user: @user,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
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
    if Administration::UpdateUser.call(
      user: @user,
      attributes: attrs.to_h,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to @user, notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :username, :user_number, :first_name, :last_name, :email,
      :password, :password_confirmation, :default_store_id, :active
    )
  end
end
