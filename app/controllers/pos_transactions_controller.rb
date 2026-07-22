# frozen_string_literal: true

class PosTransactionsController < ApplicationController
  layout "pos"

  before_action -> { require_permission!("pos.access") }, only: %i[index show]
  before_action -> { require_permission!("pos.transaction.open") }, only: %i[create]
  before_action -> { require_permission!("pos.transaction.suspend") }, only: %i[suspend]
  before_action -> { require_permission!("pos.transaction.recall") }, only: %i[recall]
  before_action -> { require_permission!("pos.transaction.cancel") }, only: %i[cancel]
  before_action -> { require_permission!("pos.transaction.complete") }, only: %i[complete]
  before_action -> { require_permission!("pos.post_void.create") },
                only: %i[post_void_form approve_post_void clear_post_void_approval post_void]
  before_action :set_transaction,
                only: %i[show suspend recall cancel complete post_void_form approve_post_void
                         clear_post_void_approval post_void]

  def index
    @suspended_transactions = Current.store.pos_transactions.suspended.order(suspended_at: :desc)
  end

  def show
    if @pos_transaction.open?
      totals = open_transaction_totals(@pos_transaction)
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
    @pos_discounts = @pos_transaction.pos_discounts
      .includes(:discount_reason, :target_pos_line_item, :pos_discount_allocations)
      .order(:position, :id)
    @line_discounts_by_line_id = @pos_discounts.select { |d| d.scope == "line" }.group_by(&:target_pos_line_item_id)
    if @pos_transaction.editable?
      @fulfillable_customer_requests = Current.store.product_requests.open_requests
        .where(request_type: "customer_request")
        .includes(:product, :product_variant)
        .order(:created_at)
        .select { |request| request.outstanding_quantity.positive? }
    end
    @transaction_discounts = @pos_discounts.select { |d| d.scope == "transaction" }
    # Sort the full hierarchy (including non-postable parents), then offer only
    # active postable departments so open-ring children keep parent-relative order.
    @departments = Department.sorted_hierarchically(
      Current.organization.departments.includes(:parent_department)
    ).select { |d| d.active? && d.postable? }
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
    @refundable_original_tenders = Pos::RefundAllocationPolicy.remaining_original_tenders(@pos_transaction)
    @card_void_confirmation = flash[:card_void_confirmation]
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

  def post_void_form
    unless @pos_transaction.completed?
      return redirect_to pos_transaction_path(@pos_transaction), alert: "Only completed transactions can be post-voided."
    end

    @eligibility = Pos::EvaluatePostVoidEligibility.call(
      original_transaction: @pos_transaction, store: Current.store
    )
    @post_void_approval = load_post_void_approval_from_session
    @card_tenders = @pos_transaction.pos_tenders.where(status: "completed").select { |t|
      t.tender_type.tender_category == "card"
    }
  end

  def approve_post_void
    unless @pos_transaction.completed?
      return redirect_to pos_transaction_path(@pos_transaction), alert: "Only completed transactions can be post-voided."
    end

    open_session = current_open_session
    return unless open_session

    approver = if params[:approver_username].present?
      User.find_by(username: params[:approver_username].to_s.strip)
    else
      Current.user
    end

    result = Pos::ApprovePostVoid.call(
      original_transaction: @pos_transaction,
      actor: Current.user,
      reason: params[:post_void_reason],
      approver: approver,
      approver_pin: params[:approver_pin],
      pos_session: open_session
    )
    if result.success?
      session[:post_void_approval] = {
        "pos_transaction_id" => @pos_transaction.id,
        "pos_approval_id" => result.pos_approval.id,
        "reason" => result.reason
      }
      notice = if @pos_transaction.pos_tenders.where(status: "completed").joins(:tender_type)
                   .where(tender_types: { tender_category: "card" }).exists?
        "Post-void approved. Reverse each card on the terminal, enter confirmations, then submit."
      else
        "Post-void approved. Submit post-void when ready."
      end
      redirect_to post_void_form_pos_transaction_path(@pos_transaction), notice: notice
    else
      redirect_to post_void_form_pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def clear_post_void_approval
    clear_post_void_approval_session!
    redirect_to post_void_form_pos_transaction_path(@pos_transaction), notice: "Post-void approval cleared."
  end

  def post_void
    open_session = current_open_session
    return unless open_session

    unless @pos_transaction.completed?
      return redirect_to pos_transaction_path(@pos_transaction), alert: "Only completed transactions can be post-voided."
    end

    approval_plan = load_post_void_approval_from_session
    if approval_plan.blank?
      return redirect_to post_void_form_pos_transaction_path(@pos_transaction),
                         alert: "Approve the post-void before submitting."
    end

    result = Pos::PostVoidTransaction.call(
      original_transaction: @pos_transaction,
      pos_session: open_session,
      actor: Current.user,
      completion_idempotency_key: params[:completion_idempotency_key].presence || SecureRandom.uuid,
      pos_approval: approval_plan[:pos_approval],
      reason: approval_plan[:reason],
      card_confirmations: card_confirmations_params
    )

    if result.success?
      clear_post_void_approval_session!
      redirect_to pos_transaction_path(result.pos_transaction),
                  notice: (result.replayed ? "Post-void already recorded." : "Post-void completed.")
    else
      redirect_to post_void_form_pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:id])
  end

  # For open returns, finalize residuals under original locks so displayed
  # balance matches tenderable amounts. Fall back to plain recalc on error.
  def open_transaction_totals(transaction)
    if transaction.pos_line_items.pending.returns.where.not(original_pos_line_item_id: nil).exists?
      ActiveRecord::Base.transaction do
        locked = PosTransaction.lock.find(transaction.id)
        return Pos::FinalizeReturnFinancials.call(pos_transaction: locked).recalculation
      end
    end
    Pos::RecalculateTransaction.call(pos_transaction: transaction)
  rescue StandardError
    Pos::RecalculateTransaction.call(pos_transaction: transaction)
  end

  def current_open_session
    open_session = Current.store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
    redirect_to register_path, alert: "Open a POS session first." if open_session.blank?
    open_session
  end

  def load_post_void_approval_from_session
    raw = session[:post_void_approval]
    return nil if raw.blank?
    return nil unless raw["pos_transaction_id"] == @pos_transaction.id

    approval = PosApproval.find_by(id: raw["pos_approval_id"])
    return nil if approval.blank?

    { pos_approval: approval, reason: raw["reason"].to_s }
  end

  def clear_post_void_approval_session!
    session.delete(:post_void_approval)
  end

  def card_confirmations_params
    raw = params[:card_confirmations]
    return {} if raw.blank?

    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    hash.each_with_object({}) do |(tender_id, attrs), out|
      next if tender_id.blank?

      attrs = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h
      out[tender_id.to_s] = {
        "external_void_confirmed" => attrs["external_void_confirmed"],
        "external_void_reference" => attrs["external_void_reference"],
        "confirmation_note" => attrs["confirmation_note"].presence || attrs["note"]
      }
    end
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
      "product_request_id" => stored["product_request_id"],
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
      .where.not(line_kind: "stored_value")
      .includes(:inventory_unit, product_variant: :product)
      .order(:position)
      .select { |line| line.remaining_returnable_quantity.positive? }
  end
end
