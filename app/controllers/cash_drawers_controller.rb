# frozen_string_literal: true

class CashDrawersController < ApplicationController
  before_action -> { require_permission!("administration.drawer.manage") }
  before_action :set_drawer, only: %i[edit update]

  def index
    @drawers = Current.store.cash_drawers.order(:code)
  end

  def new
    @drawer = Current.store.cash_drawers.new
  end

  def create
    @drawer = Current.store.cash_drawers.new(drawer_params)
    if @drawer.save
      audit!("drawer.created", @drawer)
      redirect_to cash_drawers_path, notice: "Drawer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @drawer.update(drawer_params)
      audit!("drawer.updated", @drawer)
      redirect_to cash_drawers_path, notice: "Drawer updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_drawer
    @drawer = Current.store.cash_drawers.find(params[:id])
  end

  def drawer_params
    params.require(:cash_drawer).permit(:code, :name, :active)
  end

  def audit!(action, drawer)
    Administration::RecordAuditEvent.call(
      actor: Current.user,
      organization: Current.organization,
      store: Current.store,
      action: action,
      subject: drawer,
      metadata: { code: drawer.code }
    )
  end
end
