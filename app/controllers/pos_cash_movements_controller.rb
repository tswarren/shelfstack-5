# frozen_string_literal: true

class PosCashMovementsController < ApplicationController
  include PosPendingApprovalStaging

  before_action -> { require_permission!("pos.cash_movement.create") }, only: %i[create]
  before_action :set_session

  def create
    cash_movement_type = Current.organization.cash_movement_types.find(params[:cash_movement_type_id])
    amount_cents = money_param_to_cents(params[:amount_cents], label: "Amount")

    result = Pos::CreateCashMovement.call(
      pos_session: @pos_session,
      cash_movement_type: cash_movement_type,
      amount_cents: amount_cents,
      actor: Current.user,
      reason: params[:reason],
      reference: params[:reference],
      approver: approver,
      approver_pin: params[:approver_pin]
    )

    if result.success?
      redirect_to register_path, notice: "Cash movement recorded."
    elsif result.requires_approval?
      stage_pending_approval!(
        action: "cash_movement",
        fingerprint: Pos::ApprovalInterrupt.cash_movement_fingerprint(
          pos_session: @pos_session,
          cash_movement_type_id: cash_movement_type.id,
          amount_cents: amount_cents,
          reason: params[:reason]
        ),
        payload: {
          pos_session_id: @pos_session.id,
          cash_movement_type_id: cash_movement_type.id,
          amount_cents: amount_cents,
          reason: params[:reason],
          reference: params[:reference]
        },
        presentation: Pos::ApprovalInterrupt.cash_movement_presentation(
          type_name: cash_movement_type.name,
          amount_cents: amount_cents
        )
      )
      redirect_to register_path
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
