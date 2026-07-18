# frozen_string_literal: true

class RolesController < ApplicationController
  before_action -> { require_permission!("administration.role.manage") }
  before_action :set_role, only: %i[show edit update]

  def index
    @roles = Current.organization.roles.order(:code)
  end

  def show
    @permissions = Permission.order(:code)
  end

  def new
    @role = Current.organization.roles.new
    @permissions = Permission.order(:code)
  end

  def create
    @role = Current.organization.roles.new(role_params)
    if Administration::CreateRole.call(
      role: @role,
      permission_ids: params[:permission_ids],
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to @role, notice: "Role created."
    else
      @permissions = Permission.order(:code)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @permissions = Permission.order(:code)
  end

  def update
    if Administration::UpdateRole.call(
      role: @role,
      attributes: role_params.to_h,
      permission_ids: params[:permission_ids],
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to @role, notice: "Role updated."
    else
      @permissions = Permission.order(:code)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_role
    @role = Current.organization.roles.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:code, :name, :description, :active)
  end
end
