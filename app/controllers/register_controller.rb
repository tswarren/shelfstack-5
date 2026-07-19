# frozen_string_literal: true

# Register workspace entry point: surfaces business day / session / transaction
# context and routes the cashier to the next required step.
class RegisterController < ApplicationController
  layout "pos"

  before_action -> { require_permission!("pos.access") }

  def show
    @business_day = Current.store.business_days.find_by(status: "open")
    @open_session = @business_day && Current.store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
    @open_transaction = @open_session && PosTransaction.open_transactions.find_by(active_pos_session: @open_session)
    @suspended_transactions = @business_day ? Current.store.pos_transactions.suspended.order(suspended_at: :desc) : PosTransaction.none
    @cash_movement_types = Current.organization.cash_movement_types.where(active: true).order(:name)
  end
end
