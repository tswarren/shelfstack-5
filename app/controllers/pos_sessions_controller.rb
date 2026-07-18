# frozen_string_literal: true

class PosSessionsController < ApplicationController
  before_action -> { require_permission!("pos.session.open") }, only: %i[new create]
  before_action -> { require_permission!("pos.session.close") }, only: %i[close]
  before_action :set_session, only: %i[close]

  def new
    @business_day = Current.store.business_days.find(params[:business_day_id])
    @devices = Current.store.pos_devices.where(active: true).order(:code)
    @drawers = Current.store.cash_drawers.where(active: true).order(:code)
  end

  def create
    business_day = Current.store.business_days.find(params.dig(:pos_session, :business_day_id))
    device = Current.store.pos_devices.find(params.dig(:pos_session, :pos_device_id))
    drawer_id = params.dig(:pos_session, :cash_drawer_id)
    drawer = drawer_id.presence && Current.store.cash_drawers.find(drawer_id)

    result = Pos::OpenSession.call(
      business_day: business_day,
      store: Current.store,
      pos_device: device,
      cash_drawer: drawer,
      cashier: Current.user,
      actor: Current.user
    )
    if result.success?
      redirect_to register_path, notice: "Session opened."
    else
      redirect_to new_pos_session_path(business_day_id: business_day.id), alert: result.error
    end
  end

  def close
    result = Pos::CloseSession.call(pos_session: @session, actor: Current.user)
    if result.success?
      redirect_to register_path, notice: result.replayed ? "Session already closed." : "Session closed."
    else
      redirect_to register_path, alert: result.error
    end
  end

  private

  def set_session
    @session = Current.store.pos_sessions.find(params[:id])
  end
end
