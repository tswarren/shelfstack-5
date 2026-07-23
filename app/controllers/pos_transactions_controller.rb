# frozen_string_literal: true

class PosTransactionsController < ApplicationController
  layout "pos"

  SnapshotTotals = Data.define(:subtotal_cents, :discount_total_cents, :tax_total_cents, :net_total_cents)

  before_action -> { require_permission!("pos.access") }, only: %i[index show tender]
  before_action -> { require_permission!("pos.transaction.open") }, only: %i[create]
  before_action -> { require_permission!("pos.transaction.suspend") }, only: %i[suspend]
  before_action -> { require_permission!("pos.transaction.recall") }, only: %i[recall]
  before_action -> { require_permission!("pos.transaction.cancel") }, only: %i[cancel]
  before_action -> { require_permission!("pos.transaction.complete") }, only: %i[complete]
  before_action -> { require_permission!("pos.return.create") }, only: %i[start_linked_return]
  before_action -> { require_permission!("pos.post_void.create") },
                only: %i[post_void_form approve_post_void clear_post_void_approval post_void]
  before_action :set_transaction,
                only: %i[show tender suspend recall cancel complete start_linked_return post_void_form approve_post_void
                         clear_post_void_approval post_void]
  before_action :disable_turbo_and_browser_cache, only: %i[show tender]

  def index
    @suspended_transactions = Current.store.pos_transactions.suspended.order(suspended_at: :desc)
  end

  def show
    assign_workspace_context!(presentation_param: params[:presentation])
  end

  def tender
    assign_workspace_context!(presentation_param: "tender")
    render :show
  end

  def create
    pos_session = current_open_session
    return unless pos_session

    result = Pos::OpenTransaction.call(pos_session: pos_session, actor: Current.user)
    if result.success?
      if params[:query].present?
        session[:pos_scan_resolution] = {
          "transaction_id" => result.pos_transaction.id,
          "query" => params[:query].to_s,
          "quantity" => (params[:quantity].presence || 1).to_i,
          "product_request_id" => params[:product_request_id].presence
        }
      end
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

    if PosTransaction.open_transactions.exists?(active_pos_session: session)
      return redirect_to register_path,
                         alert: "Suspend or complete the current transaction before recalling another."
    end

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
      flash[:completion_outcome] = "completed"
      redirect_to pos_transaction_path(result.pos_transaction), notice: notice
    else
      flash[:completion_outcome] = "failed"
      flash[:completion_code] = completion_failure_code(result.error)
      redirect_to pos_transaction_path(@pos_transaction, presentation: (@pos_transaction.void_required_tenders? ? nil : "tender")),
                  alert: result.error
    end
  end

  def start_linked_return
    unless @pos_transaction.completed?
      return redirect_to pos_transaction_path(@pos_transaction), alert: "Only completed receipts can start a linked return."
    end

    returnable = @pos_transaction.pos_line_items
      .where(status: "completed", direction: "sale")
      .where.not(line_kind: "stored_value")
      .any? { |line| line.remaining_returnable_quantity.positive? }
    unless returnable
      return redirect_to pos_transaction_path(@pos_transaction), alert: "No returnable lines remain on this receipt."
    end

    pos_session = current_open_session
    return unless pos_session

    open_txn = PosTransaction.open_transactions.find_by(active_pos_session: pos_session)
    unless open_txn
      require_permission!("pos.transaction.open")
      return if performed?

      opened = Pos::OpenTransaction.call(pos_session: pos_session, actor: Current.user)
      unless opened.success?
        return redirect_to pos_transaction_path(@pos_transaction), alert: opened.error
      end
      open_txn = opened.pos_transaction
    end

    session[:pos_return_lookup] = {
      "for_transaction_id" => open_txn.id,
      "original_transaction_id" => @pos_transaction.id,
      "receipt_number" => @pos_transaction.receipt_number
    }
    redirect_to pos_transaction_path(open_txn, intent: "return"),
                notice: "Receipt #{@pos_transaction.receipt_number} loaded for return."
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

  def assign_workspace_context!(presentation_param:)
    @pos_line_items = @pos_transaction.pos_line_items.where.not(status: "removed").order(:position)
    pending_lines = @pos_line_items.select(&:pending?)
    snapshots = Pos::LineFinancialSnapshots.call(pos_line_item_ids: @pos_line_items.map(&:id))
    @line_discount_cents_by_id = snapshots.discount_cents_by_id
    @line_tax_cents_by_id = snapshots.tax_cents_by_id

    if @pos_transaction.open?
      # GET-safe: sum persisted line snapshots. Do not call RecalculateTransaction
      # or FinalizeReturnFinancials from show/tender render (Phase 6.5).
      totals = snapshot_open_totals(pending_lines)
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
    @completion_idempotency_key = SecureRandom.uuid

    stored = session.delete(:pos_scan_resolution)
    if stored.present? && stored["transaction_id"] == @pos_transaction.id
      @scan_resolution = rebuild_scan_resolution(stored)
    end
    @scan_outcome = flash[:scan_outcome]
    @scan_query = flash[:scan_query]
    @entry_intent = permitted_entry_intent(params[:intent].to_s)
    @selected_line_id = params[:selected_line_id].presence&.to_i
    @selected_line = @pos_line_items.find { |line| line.id == @selected_line_id } if @selected_line_id
    @focus_target = params[:focus_target].presence
    @completion_outcome = flash[:completion_outcome]
    @completion_code = flash[:completion_code]

    if @pos_transaction.open?
      @readiness = Pos::ProjectCompletionReadiness.call(
        pos_transaction: @pos_transaction,
        discount_cents_by_id: @line_discount_cents_by_id,
        tax_cents_by_id: @line_tax_cents_by_id
      )
    end

    @workspace = Pos::WorkspacePresentation.for(
      pos_transaction: @pos_transaction,
      presentation_param: presentation_param,
      readiness: @readiness,
      net_total_cents: @net_total_cents,
      balance_due_cents: @balance_due_cents
    )
    @presentation_state = @workspace.state

    load_return_lookup!
  end

  def permitted_entry_intent(requested)
    return "sale" unless %w[sale return stored_value open_ring].include?(requested)

    case requested
    when "return"
      Current.user.can?("pos.return.create", store: Current.store) ? "return" : "sale"
    when "stored_value"
      if Current.user.can?("stored_value.issue", store: Current.store) ||
         Current.user.can?("stored_value.reload", store: Current.store)
        "stored_value"
      else
        "sale"
      end
    else
      requested
    end
  end

  def navigation_redirect_params
    {
      intent: params[:intent].presence,
      selected_line_id: params[:selected_line_id].presence,
      presentation: params[:presentation].presence,
      focus_target: params[:focus_target].presence
    }.compact
  end

  def completion_failure_code(message)
    text = message.to_s.downcase
    return "card_void_required" if text.include?("void_required")
    return "tenders_unsettled" if text.include?("do not settle")
    return "session_closed" if text.include?("session")
    return "reservation_stale" if text.include?("reservation")
    return "already_completed" if text.include?("already") || text.include?("completed")
    return "stored_value_insufficient" if text.include?("stored value") || text.include?("insufficient")

    "validation_failed"
  end

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:id])
  end

  # Prevent Turbo Drive and browser Back from restoring stale editable snapshots.
  def disable_turbo_and_browser_cache
    response.headers["Cache-Control"] = "no-store"
  end

  # Read-only totals from persisted pending-line fields (no locks, no writes).
  def snapshot_open_totals(pending_lines)
    subtotal = 0
    discount = 0
    tax = 0
    pending_lines.each do |line|
      sign = line.return? ? -1 : 1
      subtotal += sign * line.extended_price_cents.to_i
      discount += sign * @line_discount_cents_by_id.fetch(line.id, 0)
      tax += sign * @line_tax_cents_by_id.fetch(line.id, 0)
    end
    SnapshotTotals.new(
      subtotal_cents: subtotal,
      discount_total_cents: discount,
      tax_total_cents: tax,
      net_total_cents: subtotal - discount + tax
    )
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
