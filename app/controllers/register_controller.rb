# frozen_string_literal: true

# Register workspace entry point: surfaces business day / session / transaction
# context and routes the cashier to the next required step.
class RegisterController < ApplicationController
  include UnlinkedReturnRequest
  include PosImmediatePrintContext
  include PosPendingApprovalLoading
  include PosPendingApprovalStaging

  layout "pos"

  before_action -> { require_permission!("pos.access") }
  before_action -> { require_permission!("pos.transaction.open") },
                only: %i[scan_to_start lookup_receipt start_open_ring start_stored_value]
  before_action -> { require_permission!("pos.return.create") }, only: :start_unlinked_return
  before_action -> { require_permission!("pos.transaction.open") },
                only: :start_unlinked_return,
                if: -> { Current.store && current_open_session_without_transaction? }
  before_action -> {
                  require_any_permission!("pos.product_request.pickup", "requests.product_request.view")
                }, only: :start_pickup
  before_action -> { require_permission!("pos.transaction.open") },
                only: :start_pickup,
                if: -> { Current.store && current_open_session_without_transaction? }
  before_action -> { require_permission!("pos.return.create") },
                only: :lookup_receipt,
                if: -> { ActiveModel::Type::Boolean.new.cast(params[:start_linked_return]) }

  def show
    clear_immediate_print_context!
    load_register_context!
    @scan_query = flash[:scan_query]
    @scan_quantity = flash[:scan_quantity].presence || 1
    @scan_outcome = flash[:scan_outcome]
    @workspace = Pos::WorkspacePresentation.for(
      pos_transaction: nil,
      open_session: @open_session
    )
  end

  # Phase 11.3: sibling Operations workspace (Register Ops | Store Ops).
  def operations
    load_register_context!
    guard = Pos::LeaveRegisterGuard.evaluate(user: Current.user, store: Current.store)
    return render_leave_guard!(guard, destination: "operations", scope: ops_scope_param) unless guard.status == :allow

    load_register_reporting!
    load_operations_reconciliation!
    @ops_scope = ops_scope_param
    @workspace = Pos::WorkspacePresentation.for(
      pos_transaction: nil,
      open_session: @open_session
    )
    @presentation_state = "ready"
  end

  # Compatibility redirect for pre-11.3 links.
  def store_operations
    redirect_to register_operations_path(scope: "store"), status: :see_other
  end

  # OD-P11-03: leave Register for Operations or Store Workspace.
  def leave
    destination = leave_destination_param
    load_register_context!
    guard = Pos::LeaveRegisterGuard.evaluate(user: Current.user, store: Current.store)
    case guard.status
    when :allow
      redirect_to leave_redirect_path(destination, scope: params[:scope]), allow_other_host: false
    when :block
      redirect_to pos_transaction_path(guard.pos_transaction), alert: guard.message
    else
      @leave_destination = destination
      @leave_scope = params[:scope].presence
      @pos_transaction = guard.pos_transaction
      @leave_message = guard.message
      render :leave_interrupt, layout: "pos"
    end
  end

  def leave_continue
    load_register_context!
    txn = Pos::CurrentOpenTransaction.for(user: Current.user, store_id: Current.store.id)
    destination = leave_destination_param
    choice = params[:choice].to_s

    case choice
    when "return"
      return redirect_to(txn ? pos_transaction_path(txn) : register_path)
    when "suspend"
      unless txn
        return redirect_to leave_redirect_path(destination, scope: params[:scope])
      end
      require_permission!("pos.transaction.suspend")
      result = Pos::SuspendTransaction.call(pos_transaction: txn, actor: Current.user)
      unless result.success?
        return redirect_to pos_transaction_path(txn), alert: result.error
      end
    when "cancel"
      unless txn
        return redirect_to leave_redirect_path(destination, scope: params[:scope])
      end
      require_permission!("pos.transaction.cancel")
      result = Pos::CancelTransaction.call(
        pos_transaction: txn, actor: Current.user, reason: params[:reason].presence || "Left Register for Operations"
      )
      unless result.success?
        return redirect_to pos_transaction_path(txn), alert: result.error
      end
    else
      return redirect_to register_path, alert: "Choose Suspend, Cancel, or Return to Register."
    end

    redirect_to leave_redirect_path(destination, scope: params[:scope]),
                notice: (choice == "suspend" ? "Transaction suspended." : "Transaction cancelled.")
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
      product_variant_id: params[:product_variant_id],
      inventory_unit_id: params[:inventory_unit_id]
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
      redirect_to pos_transaction_path(result.pos_transaction),
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

    return if handle_unlinked_wizard!

    parse_unlinked_return_inputs!

    if unlinked_cost_review_needed?
      error = prepare_unlinked_cost_review!
      if error
        return render_unlinked_return_overlay_error(alert: error)
      end

      @cost_review_form_url = register_start_unlinked_return_path
      @cost_review_form_id = "ready_unlinked_return_cost_confirm_form"
      @cost_review_submit_label = "Confirm and start return"
      return render "pos_overlays/unlinked_return_cost_review", layout: false
    end

    result = Pos::StartUnlinkedReturn.call(
      pos_session: @open_session,
      actor: Current.user,
      **unlinked_return_service_kwargs
    )
    if result.success?
      redirect_out_of_overlay_to pos_transaction_path(result.pos_transaction),
                                notice: "Unlinked return started."
    elsif result.requires_approval?
      stage_ready_unlinked_return_approval!(result)
      redirect_out_of_overlay_to pos_transaction_path(result.pos_transaction, intent: "return")
    elsif first_step_unlinked_overlay_request?
      render_unlinked_return_overlay_error(alert: result.error)
    elsif result.pos_transaction
      redirect_out_of_overlay_to pos_transaction_path(result.pos_transaction, intent: "return"),
                                alert: result.error
    else
      redirect_out_of_overlay_to register_path, alert: result.error
    end
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    if first_step_unlinked_overlay_request?
      render_unlinked_return_overlay_error(alert: e.message)
    else
      redirect_out_of_overlay_to register_path, alert: e.message
    end
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

  def stage_ready_unlinked_return_approval!(_result)
    txn = Current.store.pos_transactions.open.order(:id).last
    return unless txn

    payload = {
      "pos_transaction_id" => txn.id,
      "product_variant_id" => @unlinked_variant&.id,
      "department_id" => @unlinked_department&.id,
      "description" => params[:description],
      "quantity" => @unlinked_quantity,
      "unit_price_cents" => @unlinked_unit_price_cents,
      "return_reason_id" => @unlinked_reason&.id,
      "return_disposition" => params[:return_disposition],
      "return_source" => params[:return_source],
      "tax_category_id" => @unlinked_tax_category&.id,
      "tax_basis" => params[:tax_basis],
      "explicit_tax_amount_cents" => @unlinked_explicit_tax,
      "cost_method" => params[:reviewed_cost_source],
      "unit_cost_cents" => params[:reviewed_cost_unit_cents],
      "cost_quality" => nil
    }
    description = @unlinked_variant&.product&.name || params[:description].presence || "Open ring"
    stage_pending_approval!(
      action: "unlinked_return",
      fingerprint: Pos::ApprovalInterrupt.unlinked_return_fingerprint(payload),
      payload: payload,
      presentation: Pos::ApprovalInterrupt.unlinked_return_presentation(
        description: description,
        quantity: @unlinked_quantity,
        unit_price_cents: @unlinked_unit_price_cents
      )
    )
  end

  def load_pending_approval_action?
    action_name == "show"
  end

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

  def current_open_session_without_transaction?
    business_day = Current.store.business_days.find_by(status: "open")
    return true unless business_day

    open_session = Current.store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
    return true unless open_session

    !PosTransaction.open_transactions.exists?(active_pos_session: open_session)
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

  def load_operations_reconciliation!
    @can_reconcile_session = Current.user.can?("reporting.reconcile_session", store: Current.store)
    @can_reconcile_business_day = Current.user.can?("reporting.reconcile_business_day", store: Current.store)

    @session_recon_required = false
    @session_reconciliation = nil
    if @open_session&.closed?
      @session_recon_required = Reporting::SessionReconciliationRequirement.required?(@open_session)
      @session_reconciliation = Reconciliation.find_by(pos_session_id: @open_session.id) if @session_recon_required
    elsif @open_session&.open?
      @session_recon_required = @open_session.cash_enabled? ||
        (Current.store.card_reconciliation_grain == "session")
    end

    @day_reconciliation = @business_day && Reconciliation.find_by(business_day_id: @business_day.id)
    @sessions_awaiting_recon = []
    return if @business_day.blank? || !@can_reconcile_session

    closed = @business_day.pos_sessions.select(&:closed?)
    @sessions_awaiting_recon = closed.select { |s|
      Reporting::SessionReconciliationRequirement.required?(s) &&
        !Reconciliation.exists?(pos_session_id: s.id, status: "finalized")
    }
  end

  def ops_scope_param
    params[:scope].to_s == "store" ? "store" : "register"
  end

  def leave_destination_param
    case params[:to].to_s
    when "store_workspace" then "store_workspace"
    when "operations_store" then "operations_store"
    else "operations_register"
    end
  end

  def leave_redirect_path(destination, scope: nil)
    case destination
    when "store_workspace" then root_path
    when "operations_store" then register_operations_path(scope: "store")
    else register_operations_path(scope: scope.presence || "register")
    end
  end

  def render_leave_guard!(guard, destination:, scope:)
    case guard.status
    when :block
      redirect_to pos_transaction_path(guard.pos_transaction), alert: guard.message
    else
      @leave_destination = destination == "operations" ? (scope == "store" ? "operations_store" : "operations_register") : destination
      @leave_scope = scope
      @pos_transaction = guard.pos_transaction
      @leave_message = guard.message
      render :leave_interrupt, layout: "pos"
    end
  end
end
