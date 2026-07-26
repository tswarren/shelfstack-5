# frozen_string_literal: true

# Register workspace entry point: surfaces business day / session / transaction
# context and routes the cashier to the next required step.
class RegisterController < ApplicationController
  layout "pos"

  before_action -> { require_permission!("pos.access") }
  before_action -> { require_permission!("pos.transaction.open") },
                only: %i[scan_to_start lookup_receipt start_open_ring start_stored_value]

  def show
    load_register_context!
    load_register_reporting!
    @scan_query = flash[:scan_query]
    @scan_quantity = flash[:scan_quantity].presence || 1
    @scan_outcome = flash[:scan_outcome]
    @workspace = Pos::WorkspacePresentation.for(
      pos_transaction: nil,
      open_session: @open_session
    )
    if @open_session.present?
      @departments = Department.sorted_hierarchically(
        Current.organization.departments.includes(:parent_department)
      )
    end
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
      # Offer opening an empty transaction so cashier can resolve candidates there.
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

  def start_stored_value
    load_register_context!
    return redirect_to register_path, alert: "Open a POS session first." if @open_session.blank?

    account = resolve_ready_stored_value_account
    return if performed?
    if account.blank?
      return redirect_to register_path, alert: "Select or create a gift-card account."
    end

    result = Pos::StartStoredValue.call(
      pos_session: @open_session,
      actor: Current.user,
      account: account,
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

  private

  def resolve_ready_stored_value_account
    if params[:create_account].present?
      unless Current.user.can?("stored_value.account.create", store: Current.store)
        redirect_to register_path, alert: "missing permission stored_value.account.create"
        return nil
      end

      created = StoredValue::CreateAccount.call(
        organization: Current.organization,
        account_type: "gift_card",
        actor: Current.user,
        store: Current.store,
        alternate_identifier: params[:alternate_identifier].presence
      )
      unless created.success?
        redirect_to register_path, alert: created.error
        return nil
      end
      return created.account
    end

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
    @suspended_transactions = @business_day ? Current.store.pos_transactions.suspended.order(suspended_at: :desc) : PosTransaction.none
    @cash_movement_types = Current.organization.cash_movement_types.where(active: true).order(:name)
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
