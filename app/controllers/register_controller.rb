# frozen_string_literal: true

# Register workspace entry point: surfaces business day / session / transaction
# context and routes the cashier to the next required step.
class RegisterController < ApplicationController
  layout "pos"

  before_action -> { require_permission!("pos.access") }
  before_action -> { require_permission!("pos.transaction.open") }, only: %i[scan_to_start lookup_receipt]

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
      quantity: params[:quantity].presence || 1
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

  private

  def load_register_context!
    @business_day = Current.store.business_days.find_by(status: "open")
    @open_session = @business_day && Current.store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
    @open_transaction = @open_session && PosTransaction.open_transactions.find_by(active_pos_session: @open_session)
    @suspended_transactions = @business_day ? Current.store.pos_transactions.suspended.order(suspended_at: :desc) : PosTransaction.none
    @cash_movement_types = Current.organization.cash_movement_types.where(active: true).order(:name)
  end

  def load_register_reporting!
    @can_view_day_x = Current.user.can?("reporting.view_business_day_x", store: Current.store)
    @can_view_day_z = Current.user.can?("reporting.view_business_day_z", store: Current.store)
    @can_view_session_x = Current.user.can?("reporting.view_session_x", store: Current.store)
    @can_view_session_z = Current.user.can?("reporting.view_session_z", store: Current.store)
    @can_view_cash = Current.user.can?("reporting.view_cash", store: Current.store)
    @day_sessions = []
    @day_totals = nil
    @session_totals_by_id = {}
    return if @business_day.blank?

    @day_sessions = @business_day.pos_sessions.includes(:pos_device, :cashier_user, :pos_session_z_report).order(:id)
    return unless @can_view_day_x || @can_view_session_x

    @day_totals = Reporting::BuildBusinessDayTotals.call(business_day: @business_day, mode: :live)
    @day_totals.session_breakdown.each do |row|
      @session_totals_by_id[row["pos_session_id"]] = row
    end
  end
end
