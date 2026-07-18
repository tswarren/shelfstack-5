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
    if @role.save
      sync_permissions!(@role)
      audit!("role.created", @role)
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
    if @role.update(role_params)
      sync_permissions!(@role)
      audit!("role.updated", @role)
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

  def sync_permissions!(role)
    selected_ids = Array(params[:permission_ids]).map(&:to_i)
    role.role_permissions.where.not(permission_id: selected_ids).find_each(&:destroy!)
    selected_ids.each do |permission_id|
      role.role_permissions.find_or_create_by!(permission_id: permission_id)
    end
  end

  def audit!(action, role)
    Administration::RecordAuditEvent.call(
      actor: Current.user,
      organization: Current.organization,
      store: Current.store,
      action: action,
      subject: role,
      metadata: { code: role.code }
    )
  end
end
