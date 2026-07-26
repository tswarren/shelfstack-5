# frozen_string_literal: true

# POS-native Customer stage / attach / remove (Phase 9).
class PosCustomersController < ApplicationController
  layout "pos"

  before_action -> { require_permission!("pos.access") }
  before_action -> { require_any_permission!("customers.customer.view", "customers.customer.lookup") }

  def stage
    session = current_open_session
    return redirect_to register_path, alert: "Open a POS session first." unless session

    customer = find_active_org_customer!
    return unless customer

    result = Pos::StageCustomer.call(pos_session: session, customer: customer, actor: Current.user)
    if result.success?
      notice = "Customer staged for next transaction."
      notice = "Previous staged customer replaced. #{notice}" if result.replaced_prior
      redirect_to register_path, notice: notice
    else
      redirect_to register_path, alert: result.error
    end
  end

  def clear_stage
    session = current_open_session
    return redirect_to register_path, alert: "Open a POS session first." unless session

    result = Pos::ClearStagedCustomer.call(pos_session: session, actor: Current.user)
    if result.success?
      redirect_to register_path, notice: "Staged customer cleared."
    else
      redirect_to register_path, alert: result.error
    end
  end

  def attach
    transaction = find_pos_transaction!
    customer = find_active_org_customer!
    return unless customer

    result = Pos::AttachCustomer.call(
      pos_transaction: transaction,
      customer: customer,
      actor: Current.user
    )
    if result.success?
      redirect_to pos_transaction_path(transaction), notice: "Customer attached."
    else
      redirect_to pos_transaction_path(transaction), alert: result.error
    end
  end

  def remove
    transaction = find_pos_transaction!
    result = Pos::RemoveCustomer.call(pos_transaction: transaction, actor: Current.user)
    if result.success?
      redirect_to pos_transaction_path(transaction), notice: "Customer removed."
    else
      redirect_to pos_transaction_path(transaction), alert: result.error
    end
  end

  private

  def current_open_session
    day = Current.store.business_days.find_by(status: "open")
    day && Current.store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
  end

  # Member routes under pos_transactions use :id (not :pos_transaction_id).
  def find_pos_transaction!
    Current.store.pos_transactions.find(params[:id])
  end

  def find_active_org_customer!
    customer = Current.organization.customers.find_by(id: params[:customer_id])
    if customer.blank?
      redirect_back fallback_location: register_path, alert: "Customer not found."
      return nil
    end
    unless customer.active?
      redirect_back fallback_location: register_path, alert: "Inactive customers cannot be used."
      return nil
    end
    customer
  end
end
