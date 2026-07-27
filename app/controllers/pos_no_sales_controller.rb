# frozen_string_literal: true

class PosNoSalesController < ApplicationController
  layout "pos"

  before_action -> { require_permission!("pos.access") }
  before_action -> { require_permission!("pos.no_sale.create") }

  def create
    session = current_open_session
    return redirect_to register_path, alert: "Open a POS session first." unless session

    result = Pos::RecordNoSale.call(
      pos_session: session,
      actor: Current.user,
      reason: params[:reason],
      idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid
    )
    if result.success?
      notice = result.replayed ? "No Sale already recorded." : "No Sale recorded."
      redirect_to register_path, notice: notice
    else
      redirect_to register_path, alert: result.error
    end
  end

  private

  def current_open_session
    day = Current.store.business_days.find_by(status: "open")
    day && Current.store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
  end
end
