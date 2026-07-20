# frozen_string_literal: true

class PosSessionsController < ApplicationController
  include PosHelper

  layout "pos"

  before_action -> { require_permission!("pos.session.open") }, only: %i[new create]
  before_action -> { require_permission!("pos.session.close") }, only: %i[close close_form]
  before_action :set_session, only: %i[close close_form]

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
    opening_cash = if drawer.present?
      money_param_to_cents(params.dig(:pos_session, :opening_cash_cents), label: "Opening cash")
    end

    result = Pos::OpenSession.call(
      business_day: business_day,
      store: Current.store,
      pos_device: device,
      cash_drawer: drawer,
      opening_cash_cents: opening_cash,
      cashier: Current.user,
      actor: Current.user
    )
    if result.success?
      redirect_to register_path, notice: "Session opened."
    else
      redirect_to new_pos_session_path(business_day_id: business_day.id), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to new_pos_session_path(business_day_id: business_day.id), alert: e.message
  end

  def close_form
    unless @session.cash_enabled?
      redirect_to register_path, alert: "Closing cash count is only required for cash-enabled sessions."
      return
    end

    @expected_cash = Pos::CalculateExpectedCash.call(pos_session: @session)
    @expected_cash_cents = @expected_cash.expected_cash_cents
    @closing_count = PosSessionCashCount
      .where(pos_session_id: @session.id, count_type: %w[closing manager_recount])
      .order(:id)
      .last
  end

  def close
    counted = if @session.cash_enabled?
      money_param_to_cents(params[:counted_cash_cents], label: "Counted cash")
    end

    result = Pos::CloseSession.call(
      pos_session: @session,
      actor: Current.user,
      counted_cash_cents: counted
    )
    if result.success?
      notice = if result.replayed
        "Session already closed."
      elsif @session.reload.cash_enabled?
        "Session closed. Variance: #{pos_money(@session.cash_variance_cents)}."
      else
        "Session closed."
      end
      redirect_to register_path, notice: notice
    else
      target = @session.cash_enabled? ? close_form_pos_session_path(@session) : register_path
      redirect_to target, alert: result.error
    end
  rescue ArgumentError => e
    target = @session.cash_enabled? ? close_form_pos_session_path(@session) : register_path
    redirect_to target, alert: e.message
  end

  private

  def set_session
    @session = Current.store.pos_sessions.find(params[:id])
  end
end
