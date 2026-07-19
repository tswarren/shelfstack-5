# frozen_string_literal: true

class PosCashMovementsController < ApplicationController
  before_action -> { require_permission!("pos.cash_movement.create") }, only: %i[create]
  before_action :set_session

  def create
    cash_movement_type = Current.organization.cash_movement_types.find(params[:cash_movement_type_id])

    result = Pos::CreateCashMovement.call(
      pos_session: @pos_session,
      cash_movement_type: cash_movement_type,
      amount_cents: money_param_to_cents(params[:amount_cents], label: "Amount"),
      actor: Current.user,
      reason: params[:reason],
      reference: params[:reference],
      approver: approver,
      approver_pin: params[:approver_pin]
    )

    if result.success?
      redirect_to register_path, notice: "Cash movement recorded."
    else
      redirect_to register_path, alert: result.error
    end
  rescue ArgumentError => e
    redirect_to register_path, alert: e.message
  end

  private

  def set_session
    @pos_session = Current.store.pos_sessions.find(params[:pos_session_id])
  end

  def approver
    params[:approver_username].presence && User.find_by(username: params[:approver_username])
  end
end
