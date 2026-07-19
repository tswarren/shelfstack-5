# frozen_string_literal: true

class PosTransactionsController < ApplicationController
  before_action -> { require_permission!("pos.access") }, only: %i[index show]
  before_action -> { require_permission!("pos.transaction.open") }, only: %i[create]
  before_action -> { require_permission!("pos.transaction.suspend") }, only: %i[suspend]
  before_action -> { require_permission!("pos.transaction.recall") }, only: %i[recall]
  before_action -> { require_permission!("pos.transaction.cancel") }, only: %i[cancel]
  before_action :set_transaction, only: %i[show suspend recall cancel]

  def index
    @suspended_transactions = Current.store.pos_transactions.suspended.order(suspended_at: :desc)
  end

  def show
    @pos_line_items = @pos_transaction.pos_line_items.where.not(status: "removed").order(:position)
    @removed_line_items = @pos_transaction.pos_line_items.where(status: "removed").order(:position)
    @departments = Current.organization.departments.where(active: true, postable: true).order(:name)
    @tax_categories = Current.organization.tax_categories.where(active: true).order(:name)
    @discount_reasons = Current.organization.discount_reasons.where(active: true).order(:name)

    @subtotal_cents = @pos_line_items.sum(&:extended_price_cents)
    @discount_total_cents = @pos_line_items.sum(&:discount_amount_cents)
    @tax_total_cents = @pos_line_items.sum(&:tax_amount_cents)
    @net_total_cents = @subtotal_cents - @discount_total_cents + @tax_total_cents
  end

  def create
    session = current_open_session
    return unless session

    result = Pos::OpenTransaction.call(pos_session: session, actor: Current.user)
    if result.success?
      redirect_to pos_transaction_path(result.pos_transaction)
    else
      redirect_to register_path, alert: result.error
    end
  end

  def suspend
    result = Pos::SuspendTransaction.call(pos_transaction: @pos_transaction, actor: Current.user)
    if result.success?
      redirect_to register_path, notice: "Transaction suspended."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def recall
    session = current_open_session
    return unless session

    result = Pos::RecallTransaction.call(pos_transaction: @pos_transaction, pos_session: session, actor: Current.user)
    if result.success?
      redirect_to pos_transaction_path(result.pos_transaction)
    else
      redirect_to register_path, alert: result.error
    end
  end

  def cancel
    result = Pos::CancelTransaction.call(pos_transaction: @pos_transaction, actor: Current.user, reason: params[:reason])
    if result.success?
      redirect_to register_path, notice: "Transaction cancelled."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:id])
  end

  def current_open_session
    session = Current.store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
    redirect_to register_path, alert: "Open a POS session first." if session.blank?
    session
  end
end
