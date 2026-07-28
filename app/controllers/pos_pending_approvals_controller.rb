# frozen_string_literal: true

# Approve or cancel a session-staged POS pending approval action (Phase 11.2A).
class PosPendingApprovalsController < ApplicationController
  before_action -> { require_permission!("pos.access") }
  before_action :require_pending!

  def create
    pending = @pending_approval_action
    approver = resolve_approver
    unless approver
      return redirect_back_to_context(alert: "Enter an approver username (or leave blank to self-approve when permitted).")
    end

    result = replay(pending, approver: approver, approver_pin: params[:approver_pin])
    if result[:success]
      Pos::PendingApprovalAction.clear!(session)
      redirect_to result[:path], notice: result[:notice]
    else
      redirect_to result[:path], alert: result[:error]
    end
  end

  def destroy
    Pos::PendingApprovalAction.clear!(session)
    redirect_to cancel_path, notice: "Approval cancelled."
  end

  private

  def require_pending!
    @pending_approval_action = Pos::PendingApprovalAction.load(session)
    return if @pending_approval_action.present?

    Pos::PendingApprovalAction.clear!(session)
    redirect_to register_path, alert: "No pending approval to continue."
  end

  def resolve_approver
    if params[:approver_username].present?
      User.find_by(username: params[:approver_username].to_s.strip)
    else
      Current.user
    end
  end

  def replay(pending, approver:, approver_pin:)
    case pending.action
    when "price_override"
      replay_price_override(pending, approver:, approver_pin:)
    when "discount"
      replay_discount(pending, approver:, approver_pin:)
    when "tax_override"
      replay_tax_override(pending, approver:, approver_pin:)
    when "cash_movement"
      replay_cash_movement(pending, approver:, approver_pin:)
    when "unlinked_return"
      replay_unlinked_return(pending, approver:, approver_pin:)
    when "refund_exception"
      replay_refund_exception(pending, approver:, approver_pin:)
    else
      { success: false, path: register_path, error: "Unknown pending approval action." }
    end
  end

  def replay_price_override(pending, approver:, approver_pin:)
    payload = pending.payload
    txn = Current.store.pos_transactions.find(payload["pos_transaction_id"])
    line = txn.pos_line_items.find(payload["pos_line_item_id"])
    requested = payload["requested_unit_price_cents"].to_i
    reason = payload["reason"]

    fingerprint = Pos::ApprovalInterrupt.price_override_fingerprint(
      pos_line_item: line, requested_unit_price_cents: requested, reason: reason
    )
    unless pending.matches_fingerprint?(fingerprint)
      Pos::PendingApprovalAction.clear!(session)
      return { success: false, path: pos_transaction_path(txn), error: "The price override changed; approval was cleared. Try again." }
    end

    result = Pos::OverridePrice.call(
      pos_line_item: line,
      requested_unit_price_cents: requested,
      actor: Current.user,
      reason: reason,
      approver: approver,
      approver_pin: approver_pin
    )
    path = pos_transaction_path(txn, intent: payload["intent"], selected_line_id: payload["selected_line_id"], focus_target: payload["focus_target"])
    if result.success?
      { success: true, path: path, notice: "Price overridden." }
    else
      { success: false, path: path, error: result.error }
    end
  end

  def replay_discount(pending, approver:, approver_pin:)
    payload = pending.payload
    txn = Current.store.pos_transactions.find(payload["pos_transaction_id"])
    line = payload["pos_line_item_id"].present? ? txn.pos_line_items.find_by(id: payload["pos_line_item_id"]) : nil
    fingerprint = Pos::ApprovalInterrupt.discount_fingerprint(
      pos_transaction: txn,
      scope: payload["scope"],
      pos_line_item_id: payload["pos_line_item_id"],
      method: payload["method"],
      rate_bps: payload["rate_bps"],
      amount_cents: payload["amount_cents"],
      reason: payload["reason"]
    )
    unless pending.matches_fingerprint?(fingerprint)
      Pos::PendingApprovalAction.clear!(session)
      return { success: false, path: pos_transaction_path(txn), error: "The discount changed; approval was cleared. Try again." }
    end

    result = Pos::ApplyDiscount.call(
      pos_transaction: txn,
      scope: payload["scope"],
      pos_line_item: line,
      method: payload["method"],
      rate_bps: payload["rate_bps"],
      amount_cents: payload["amount_cents"],
      discount_reason: payload["discount_reason_id"].present? ? Current.organization.discount_reasons.find_by(id: payload["discount_reason_id"]) : nil,
      reason: payload["reason"],
      actor: Current.user,
      approver: approver,
      approver_pin: approver_pin
    )
    path = pos_transaction_path(txn, intent: payload["intent"], selected_line_id: payload["selected_line_id"], focus_target: payload["focus_target"])
    if result.success?
      { success: true, path: path, notice: "Discount applied." }
    else
      { success: false, path: path, error: result.error }
    end
  end

  def replay_tax_override(pending, approver:, approver_pin:)
    payload = pending.payload
    txn = Current.store.pos_transactions.find(payload["pos_transaction_id"])
    line = txn.pos_line_items.find(payload["pos_line_item_id"])
    tax_category = Current.organization.tax_categories.find(payload["tax_category_id"])
    fingerprint = Pos::ApprovalInterrupt.tax_override_fingerprint(
      pos_line_item: line, tax_category_id: tax_category.id, reason: payload["reason"]
    )
    unless pending.matches_fingerprint?(fingerprint)
      Pos::PendingApprovalAction.clear!(session)
      return { success: false, path: pos_transaction_path(txn), error: "The tax override changed; approval was cleared. Try again." }
    end

    result = Pos::OverrideTaxCategory.call(
      pos_line_item: line,
      tax_category: tax_category,
      reason: payload["reason"],
      actor: Current.user,
      approver: approver,
      approver_pin: approver_pin
    )
    path = pos_transaction_path(txn, intent: payload["intent"], selected_line_id: payload["selected_line_id"], focus_target: payload["focus_target"])
    if result.success?
      { success: true, path: path, notice: "Tax category overridden." }
    else
      { success: false, path: path, error: result.error }
    end
  end

  def replay_cash_movement(pending, approver:, approver_pin:)
    payload = pending.payload
    session_rec = Current.store.pos_sessions.find(payload["pos_session_id"])
    type = CashMovementType.find(payload["cash_movement_type_id"])
    fingerprint = Pos::ApprovalInterrupt.cash_movement_fingerprint(
      pos_session: session_rec,
      cash_movement_type_id: type.id,
      amount_cents: payload["amount_cents"],
      reason: payload["reason"]
    )
    unless pending.matches_fingerprint?(fingerprint)
      Pos::PendingApprovalAction.clear!(session)
      return { success: false, path: register_path, error: "The cash movement changed; approval was cleared. Try again." }
    end

    result = Pos::CreateCashMovement.call(
      pos_session: session_rec,
      cash_movement_type: type,
      amount_cents: payload["amount_cents"].to_i,
      reason: payload["reason"],
      actor: Current.user,
      approver: approver,
      approver_pin: approver_pin
    )
    if result.success?
      { success: true, path: register_path, notice: "Cash movement recorded." }
    else
      { success: false, path: register_path, error: result.error }
    end
  end

  def replay_unlinked_return(pending, approver:, approver_pin:)
    payload = pending.payload
    txn = Current.store.pos_transactions.find(payload["pos_transaction_id"])
    fingerprint = Pos::ApprovalInterrupt.unlinked_return_fingerprint(payload)
    unless pending.matches_fingerprint?(fingerprint)
      Pos::PendingApprovalAction.clear!(session)
      return { success: false, path: pos_transaction_path(txn), error: "The return changed; approval was cleared. Try again." }
    end

    variant = if payload["product_variant_id"].present?
      ProductVariant.joins(:product).where(products: { organization_id: Current.organization.id })
        .find_by(id: payload["product_variant_id"])
    end
    department = payload["department_id"].present? ? Current.organization.departments.find_by(id: payload["department_id"]) : nil
    reason = Current.organization.return_reasons.find_by(id: payload["return_reason_id"])

    result = Pos::AddUnlinkedReturnLine.call(
      pos_transaction: txn,
      actor: Current.user,
      product_variant: variant,
      department: department,
      description: payload["description"],
      quantity: payload["quantity"],
      unit_price_cents: payload["unit_price_cents"],
      return_reason: reason,
      return_disposition: payload["return_disposition"],
      return_source: payload["return_source"],
      tax_category: payload["tax_category_id"].present? ? Current.organization.tax_categories.find_by(id: payload["tax_category_id"]) : nil,
      tax_basis: payload["tax_basis"],
      explicit_tax_amount_cents: payload["explicit_tax_amount_cents"],
      cost_method: payload["cost_method"],
      unit_cost_cents: payload["unit_cost_cents"],
      cost_quality: payload["cost_quality"],
      confirm_cost_basis: true,
      approver: approver,
      approver_pin: approver_pin
    )
    path = pos_transaction_path(txn, intent: "return")
    if result.success?
      { success: true, path: path, notice: "Return line added." }
    else
      { success: false, path: path, error: result.error }
    end
  end

  def replay_refund_exception(pending, approver:, approver_pin:)
    payload = pending.payload
    txn = Current.store.pos_transactions.find(payload["pos_transaction_id"])
    fingerprint = Pos::ApprovalInterrupt.refund_exception_fingerprint(
      pos_transaction: txn,
      destination: payload["destination"],
      amount_cents: payload["amount_cents"],
      original_tender_id: payload["original_pos_tender_id"]
    )
    unless pending.matches_fingerprint?(fingerprint)
      Pos::PendingApprovalAction.clear!(session)
      return { success: false, path: tender_pos_transaction_path(txn), error: "The refund changed; approval was cleared. Try again." }
    end

    tender_type = Current.organization.tender_types.find(payload["tender_type_id"])
    original = payload["original_pos_tender_id"].present? ? PosTender.find_by(id: payload["original_pos_tender_id"]) : nil
    result = case payload["destination"]
    when "cash"
      Pos::AddCashRefundTender.call(
        pos_transaction: txn,
        tender_type: tender_type,
        amount_cents: payload["amount_cents"].to_i,
        actor: Current.user,
        original_pos_tender: original,
        exception_approver: approver,
        exception_approver_pin: approver_pin
      )
    when "card"
      Pos::AddCardRefundTender.call(
        pos_transaction: txn,
        tender_type: tender_type,
        amount_cents: payload["amount_cents"].to_i,
        actor: Current.user,
        original_pos_tender: original,
        authorization_code: payload["authorization_code"],
        terminal_reference: payload["terminal_reference"],
        exception_approver: approver,
        exception_approver_pin: approver_pin,
        recording_idempotency_key: payload["recording_idempotency_key"].presence || SecureRandom.uuid
      )
    when "new_stored_value", "original_stored_value"
      account = Current.organization.stored_value_accounts.find_by(id: payload["stored_value_account_id"])
      Pos::AddStoredValueRefundTender.call(
        pos_transaction: txn,
        tender_type: tender_type,
        amount_cents: payload["amount_cents"].to_i,
        actor: Current.user,
        account: account,
        original_pos_tender: original,
        create_store_credit: ActiveModel::Type::Boolean.new.cast(payload["create_store_credit"]),
        exception_approver: approver,
        exception_approver_pin: approver_pin
      )
    else
      return { success: false, path: tender_pos_transaction_path(txn), error: "Unknown refund destination." }
    end

    if result.success?
      { success: true, path: tender_pos_transaction_path(txn), notice: "Refund tender recorded." }
    else
      { success: false, path: tender_pos_transaction_path(txn), error: result.error }
    end
  end

  def cancel_path
    payload = @pending_approval_action.payload
    if payload["pos_transaction_id"].present?
      txn = Current.store.pos_transactions.find_by(id: payload["pos_transaction_id"])
      return pos_transaction_path(txn) if txn
    end
    register_path
  end

  def redirect_back_to_context(alert:)
    redirect_to cancel_path, alert: alert
  end
end
