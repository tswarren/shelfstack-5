# frozen_string_literal: true

# Register workspace entry point: surfaces business day / session / transaction
# context and routes the cashier to the next required step.
class RegisterController < ApplicationController
  layout "pos"

  before_action -> { require_permission!("pos.access") }
  before_action -> { require_permission!("pos.transaction.open") },
                only: %i[scan_to_start lookup_receipt start_open_ring start_stored_value]
  before_action -> { require_permission!("pos.return.create") }, only: :start_unlinked_return
  before_action -> {
                  require_any_permission!("pos.product_request.pickup", "requests.product_request.view")
                }, only: :start_pickup
  before_action -> { require_permission!("pos.return.create") },
                only: :lookup_receipt,
                if: -> { ActiveModel::Type::Boolean.new.cast(params[:start_linked_return]) }

  def show
    load_register_context!
    @scan_query = flash[:scan_query]
    @scan_quantity = flash[:scan_quantity].presence || 1
    @scan_outcome = flash[:scan_outcome]
    @workspace = Pos::WorkspacePresentation.for(
      pos_transaction: nil,
      open_session: @open_session
    )
  end

  # POS-UI-037: session/day close and X/Z reports live here, not on Ready.
  def store_operations
    load_register_context!
    load_register_reporting!
    @workspace = Pos::WorkspacePresentation.for(
      pos_transaction: nil,
      open_session: @open_session
    )
    @presentation_state = "ready"
  end

  def scan_to_start
    load_register_context!
    session = @open_session
    if session.blank?
      return redirect_to register_path, alert: "Open a POS session first."
    end

    if @open_transaction.blank? && !Current.user.can?("pos.transaction.open", store: Current.store)
      return redirect_to register_path, alert: "You do not have permission to start a transaction."
    end

    result = Pos::ScanToStart.call(
      pos_session: session,
      actor: Current.user,
      query: params[:query],
      quantity: params[:quantity].presence || 1,
      product_variant_id: params[:product_variant_id]
    )

    if result.success?
      flash[:scan_outcome] = "added"
      flash[:notice] = "Line added." if result.warnings.blank?
      flash[:notice] = result.warnings.join(" ") if result.warnings.any?
      redirect_to pos_transaction_path(result.pos_transaction)
    elsif result.outcome == "ambiguous"
      flash[:scan_outcome] = "ambiguous"
      flash[:scan_query] = params[:query].to_s
      flash[:scan_quantity] = (params[:quantity].presence || 1).to_i
      flash[:alert] = result.error
      redirect_to register_path
    elsif result.outcome == "customer_conflict"
      flash[:scan_outcome] = "customer_conflict"
      flash[:scan_query] = params[:query].to_s
      redirect_to pos_transaction_path(result.pos_transaction), alert: result.error
    else
      flash[:scan_outcome] = result.outcome
      flash[:scan_query] = params[:query].to_s
      redirect_to(result.pos_transaction ? pos_transaction_path(result.pos_transaction) : register_path,
                  alert: result.error)
    end
  end

  def lookup_receipt
    load_register_context!
    receipt_number = params[:receipt_number].to_s.strip
    if receipt_number.blank?
      return redirect_to register_path, alert: "Enter a receipt number."
    end

    txn = Current.store.pos_transactions.completed.find_by(receipt_number: receipt_number)
    if txn.blank?
      return redirect_to register_path, alert: "No completed receipt found for that number."
    end

    if ActiveModel::Type::Boolean.new.cast(params[:start_linked_return])
      return start_linked_return_from_lookup!(txn)
    end

    redirect_to pos_transaction_path(txn)
  end

  def start_open_ring
    load_register_context!
    return redirect_to register_path, alert: "Open a POS session first." if @open_session.blank?

    department = Current.organization.departments.find_by(id: params[:department_id])
    result = Pos::StartOpenRing.call(
      pos_session: @open_session,
      actor: Current.user,
      department: department,
      unit_price_cents: money_param_to_cents(params[:unit_price_cents], label: "Price"),
      quantity: params[:quantity].presence || 1,
      description: params[:description]
    )
    if result.success?
      redirect_to pos_transaction_path(result.pos_transaction, intent: "open_ring"),
                  notice: "Open-ring line added."
    elsif result.pos_transaction
      redirect_to pos_transaction_path(result.pos_transaction), alert: result.error
    else
      redirect_to register_path, alert: result.error
    end
  rescue ArgumentError => e
    redirect_to register_path, alert: e.message
  end

  def start_unlinked_return
    load_register_context!
    return redirect_to register_path, alert: "Open a POS session first." if @open_session.blank?

    reason = Current.organization.return_reasons.find(params[:return_reason_id])
    variant = params[:product_variant_id].presence &&
      ProductVariant.joins(:product)
        .where(products: { organization_id: Current.organization.id })
        .find_by(id: params[:product_variant_id])
    department = params[:department_id].presence &&
      Current.organization.departments.find_by(id: params[:department_id])
    approver = params[:approver_username].presence &&
      User.find_by(username: params[:approver_username].to_s.strip.downcase)
    tax_category = params[:tax_category_id].presence &&
      Current.organization.tax_categories.find_by(id: params[:tax_category_id])
    explicit_tax = if params[:tax_basis].to_s == "external_receipt_tax"
      money_param_to_cents(params[:explicit_tax_amount_cents], label: "Explicit tax amount", required: false)
    end

    result = Pos::StartUnlinkedReturn.call(
      pos_session: @open_session,
      actor: Current.user,
      return_source: params[:return_source],
      return_reason: reason,
      return_disposition: params[:return_disposition],
      unit_price_cents: money_param_to_cents(params[:unit_price_cents], label: "Refund unit price"),
      quantity: params[:quantity].presence || 1,
      product_variant: variant,
      department: department,
      description: params[:description],
      tax_category: tax_category,
      tax_basis: params[:tax_basis],
      explicit_tax_amount_cents: explicit_tax,
      confirm_cost_basis: params[:confirm_cost_basis],
      confirmed_unit_cost_cents: nil,
      approver: approver,
      approver_pin: params[:approver_pin]
    )
    if result.success?
      redirect_to pos_transaction_path(result.pos_transaction),
                  notice: "Unlinked return started."
    elsif result.pos_transaction
      redirect_to pos_transaction_path(result.pos_transaction, intent: "return"), alert: result.error
    else
      redirect_to register_path, alert: result.error
    end
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    redirect_to register_path, alert: e.message
  end

  def start_stored_value
    load_register_context!
    return redirect_to register_path, alert: "Open a POS session first." if @open_session.blank?

    create_account = params[:create_account].present?
    if create_account && !Current.user.can?("stored_value.account.create", store: Current.store)
      return redirect_to register_path, alert: "missing permission stored_value.account.create"
    end

    account = nil
    unless create_account
      account = resolve_ready_stored_value_account
      if account.blank?
        return redirect_to register_path, alert: "Select or create a gift-card account."
      end
    end

    result = Pos::StartStoredValue.call(
      pos_session: @open_session,
      actor: Current.user,
      account: account,
      create_account: create_account,
      organization: Current.organization,
      store: Current.store,
      alternate_identifier: params[:alternate_identifier].presence,
      operation: params[:stored_value_operation].presence || "issue",
      amount_cents: money_param_to_cents(params[:amount_cents], label: "Amount")
    )
    if result.success?
      redirect_to pos_transaction_path(result.pos_transaction, intent: "stored_value"),
                  notice: "Stored-value line added."
    elsif result.pos_transaction
      redirect_to pos_transaction_path(result.pos_transaction), alert: result.error
    else
      redirect_to register_path, alert: result.error
    end
  rescue ArgumentError => e
    redirect_to register_path, alert: e.message
  end

  def start_pickup
    load_register_context!
    return redirect_to register_path, alert: "Open a POS session first." if @open_session.blank?

    product_request = Current.store.product_requests.find_by(id: params[:product_request_id])
    result = Pos::StartPickup.call(
      pos_session: @open_session,
      actor: Current.user,
      product_request: product_request,
      quantity: params[:quantity].presence || 1
    )
    if result.success?
      redirect_to pos_transaction_path(result.pos_transaction, intent: "sale"),
                  notice: "Pickup line added."
    elsif result.pos_transaction
      redirect_to pos_transaction_path(result.pos_transaction), alert: result.error
    else
      redirect_to register_path, alert: result.error
    end
  end

  private

  def start_linked_return_from_lookup!(original)
    returnable = original.pos_line_items
      .where(status: "completed", direction: "sale")
      .where.not(line_kind: "stored_value")
      .any? { |line| line.remaining_returnable_quantity.positive? }
    unless returnable
      return redirect_to pos_transaction_path(original), alert: "No returnable lines remain on this receipt."
    end

    if @open_session.blank?
      return redirect_to register_path, alert: "Open a POS session first."
    end

    can_open = Current.user.can?("pos.transaction.open", store: Current.store)
    opened = Pos::FindOrOpenActiveTransaction.call(
      pos_session: @open_session,
      actor: Current.user,
      create_if_missing: can_open
    )
    unless opened.success?
      return redirect_to pos_transaction_path(original), alert: opened.error
    end

    open_txn = opened.pos_transaction
    session[:pos_return_lookup] = {
      "for_transaction_id" => open_txn.id,
      "original_transaction_id" => original.id,
      "receipt_number" => original.receipt_number
    }
    redirect_to pos_transaction_path(open_txn),
                notice: "Receipt #{original.receipt_number} loaded for return."
  end

  def resolve_ready_stored_value_account
    identifier = params[:account_number].presence || params[:alternate_identifier].presence
    return nil if identifier.blank?

    StoredValue::ResolveAccount.call(
      organization: Current.organization, identifier: identifier
    ).account
  rescue StoredValue::ResolveAccount::Error
    nil
  end


  def load_register_context!
    @business_day = Current.store.business_days.find_by(status: "open")
    @open_session = @business_day && Current.store.pos_sessions.open_sessions
      .includes(:staged_customer, :staged_customer_by_user)
      .find_by(cashier_user: Current.user)
    @open_transaction = @open_session && PosTransaction.open_transactions.find_by(active_pos_session: @open_session)
    suspended_scope = @business_day ? Current.store.pos_transactions.suspended.order(suspended_at: :desc) : PosTransaction.none
    @suspended_count = suspended_scope.count
    @suspended_transactions = suspended_scope.limit(3)
    @can_view_customers = Current.user.can?("customers.customer.view", store: Current.store) ||
      Current.user.can?("customers.customer.lookup", store: Current.store)
  end

  def load_register_reporting!
    @can_view_day_x = Current.user.can?("reporting.view_business_day_x", store: Current.store)
    @can_view_day_z = Current.user.can?("reporting.view_business_day_z", store: Current.store)
    @can_view_session_x = Current.user.can?("reporting.view_session_x", store: Current.store)
    @can_view_session_z = Current.user.can?("reporting.view_session_z", store: Current.store)
    @day_sessions = []
    return if @business_day.blank?

    # Ready keeps session/day actions and report links only — not live sales/tender/cash KPIs.
    @day_sessions = @business_day.pos_sessions.includes(:pos_device, :cashier_user, :pos_session_z_report).order(:id)
  end
end
