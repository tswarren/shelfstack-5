# frozen_string_literal: true

class PosTransactionsController < ApplicationController
  layout "pos"

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
    @change_due_cents = @pos_tenders.sum { |t| t.change_due_cents.to_i }
    # Stable per page-render so a double-click / back-button resubmit of the
    # completion form reuses the same idempotency key (ADR-0009).
    @completion_idempotency_key = SecureRandom.uuid

    # Actionable scan resolution after an ambiguous scan (POST → PRG).
    # Session stores only { transaction_id, query, quantity }; candidates rebuilt here.
    stored = session.delete(:pos_scan_resolution)
    if stored.present? && stored["transaction_id"] == @pos_transaction.id
      @scan_resolution = rebuild_scan_resolution(stored)
    end
    @scan_outcome = flash[:scan_outcome]
    @scan_query = flash[:scan_query]

    load_return_lookup!
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
      # Structured recall detail is surfaced on the transaction show page
      # (see pos_transactions/_recall_summary) rather than crammed into flash text.
      changes = result.changes.map { |c| "Line #{c.pos_line_item_id}: #{c.field} #{c.from} → #{c.to}" }
      flash[:recall_changes] = changes if changes.any?
      flash[:recall_warnings] = result.warnings if result.warnings.any?
      flash[:recall_blockers] = result.blockers if result.blockers.any?

      redirect_to pos_transaction_path(result.pos_transaction), notice: "Transaction recalled."
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

  def rebuild_scan_resolution(stored)
    lookup = Catalog::Lookup.call(organization: Current.organization, query: stored["query"])
    candidates = lookup.products.first(10).map do |product|
      {
        "product_id" => product.id,
        "title" => product.name,
        "identifier" => product.identifier,
        "variants" => product.product_variants.map { |v|
          label = "#{v.name.presence || 'Standard'} · SKU #{v.sku}"
          { "id" => v.id, "sku" => v.sku, "label" => label }
        }
      }
    end

    {
      "query" => stored["query"].to_s,
      "quantity" => (stored["quantity"].presence || 1).to_i,
      "candidates" => candidates
    }
  end

  def load_return_lookup!
    stored = session[:pos_return_lookup]
    return if stored.blank? || stored["for_transaction_id"] != @pos_transaction.id

    original_txn = Current.store.pos_transactions.completed.find_by(id: stored["original_transaction_id"])
    if original_txn.blank?
      session.delete(:pos_return_lookup)
      return
    end

    @return_lookup_transaction = original_txn
    @return_lookup_lines = original_txn.pos_line_items
      .where(status: "completed", direction: "sale")
      .includes(:product_variant, product_variant: :product)
      .order(:position)
      .select { |line| line.remaining_returnable_quantity.positive? }
  end
end
