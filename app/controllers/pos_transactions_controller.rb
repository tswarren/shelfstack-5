# frozen_string_literal: true

class PosTransactionsController < ApplicationController
  before_action -> { require_permission!("pos.access") }, only: %i[index show]
  before_action -> { require_permission!("pos.transaction.open") }, only: %i[create]
  before_action -> { require_permission!("pos.transaction.suspend") }, only: %i[suspend]
  before_action -> { require_permission!("pos.transaction.recall") }, only: %i[recall]
  before_action -> { require_permission!("pos.transaction.cancel") }, only: %i[cancel]
  before_action -> { require_permission!("pos.transaction.complete") }, only: %i[complete]
  before_action :set_transaction, only: %i[show suspend recall cancel complete]

  def index
    @suspended_transactions = Current.store.pos_transactions.suspended.order(suspended_at: :desc)
  end

  def show
    if @pos_transaction.open?
      totals = Pos::RecalculateTransaction.call(pos_transaction: @pos_transaction)
      @subtotal_cents = totals.subtotal_cents
      @discount_total_cents = totals.discount_total_cents
      @tax_total_cents = totals.tax_total_cents
      @net_total_cents = totals.net_total_cents
    else
      @subtotal_cents = @pos_transaction.subtotal_cents || 0
      @discount_total_cents = @pos_transaction.discount_total_cents || 0
      @tax_total_cents = @pos_transaction.tax_total_cents || 0
      @net_total_cents = @pos_transaction.net_total_cents || 0
    end

    # Load lines after recalculation so provisional tax associations are fresh.
    @pos_line_items = @pos_transaction.pos_line_items.where.not(status: "removed").order(:position)
    @removed_line_items = @pos_transaction.pos_line_items.where(status: "removed").order(:position)
    @departments = Current.organization.departments.where(active: true, postable: true).order(:name)
    @tax_categories = Current.organization.tax_categories.where(active: true).order(:name)
    @discount_reasons = Current.organization.discount_reasons.where(active: true).order(:name)
    @return_reasons = Current.organization.return_reasons.where(active: true).order(:name)

    @tender_types = Current.organization.tender_types.where(active: true).order(:name)
    @pos_tenders = @pos_transaction.pos_tenders.where.not(status: "removed").order(:created_at)
    received = @pos_transaction.pos_tenders.unresolved.where(direction: "received").sum(:amount_cents) +
      @pos_transaction.pos_tenders.where(status: "completed", direction: "received").sum(:amount_cents)
    refunded = @pos_transaction.pos_tenders.unresolved.where(direction: "refunded").sum(:amount_cents) +
      @pos_transaction.pos_tenders.where(status: "completed", direction: "refunded").sum(:amount_cents)
    @tendered_total_cents = received - refunded
    @balance_due_cents = @net_total_cents - @tendered_total_cents
    # Stable per page-render so a double-click / back-button resubmit of the
    # completion form reuses the same idempotency key (ADR-0009).
    @completion_idempotency_key = SecureRandom.uuid
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
      notices = []
      alerts = []
      if result.changes.any?
        notices << "Recall refreshed commercial values: " + result.changes.map { |c|
          "line #{c.pos_line_item_id} #{c.field} #{c.from} → #{c.to}"
        }.join("; ")
      end
      notices.concat(result.warnings) if result.warnings.any?
      alerts.concat(result.blockers.map { |b| "Eligibility blocker: #{b}" }) if result.blockers.any?

      redirect_opts = { notice: notices.presence&.join(" | ") || (alerts.empty? ? "Transaction recalled." : nil) }
      redirect_opts[:alert] = alerts.join(" | ") if alerts.any?
      redirect_to pos_transaction_path(result.pos_transaction), redirect_opts.compact
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

  def complete
    session = current_open_session
    return unless session

    result = Pos::CompleteTransaction.call(
      pos_transaction: @pos_transaction, pos_session: session, actor: Current.user,
      completion_idempotency_key: params[:completion_idempotency_key].presence || SecureRandom.uuid
    )
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Transaction completed."
      redirect_to pos_transaction_path(result.pos_transaction), notice: notice
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
