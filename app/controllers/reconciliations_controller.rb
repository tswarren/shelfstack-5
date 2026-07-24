# frozen_string_literal: true

class ReconciliationsController < ApplicationController
  def index
    unless Current.user.can?("reporting.reconcile_session", store: Current.store) ||
        Current.user.can?("reporting.reconcile_business_day", store: Current.store)
      redirect_to root_path, alert: "You are not authorized to perform that action."
      return
    end

    closed = Current.store.pos_sessions.where(status: "closed", reconciled_at: nil)
      .includes(:business_day, :reconciliation, :cash_drawer, :store)
      .order(closed_at: :desc)
    @pending_sessions = closed.select { |session| Reporting::SessionReconciliationRequirement.required?(session) }
    @pending_days = Current.store.business_days
      .where(status: "closed", reconciled_at: nil)
      .order(closed_at: :desc)
  end

  def session_show
    require_permission!("reporting.reconcile_session")
    @session = Current.store.pos_sessions.find(params[:pos_session_id])
    result = Reporting::AssembleSessionReconciliation.call(pos_session: @session, actor: Current.user)
    unless result.success?
      redirect_to reconciliations_path, alert: result.error
      return
    end
    @reconciliation = result.reconciliation
  end

  def business_day_show
    require_permission!("reporting.reconcile_business_day")
    @business_day = Current.store.business_days.find(params[:business_day_id])
    result = Reporting::AssembleBusinessDayReconciliation.call(business_day: @business_day, actor: Current.user)
    unless result.success?
      redirect_to reconciliations_path, alert: result.error
      return
    end
    @reconciliation = result.reconciliation
  end

  def finalize
    @reconciliation = Current.store.reconciliations.find(params[:id])
    result = Reporting::FinalizeReconciliation.call(
      reconciliation: @reconciliation,
      actor: Current.user,
      reason: params[:reason],
      approver: params[:approver_username].present? ? User.find_by(username: params[:approver_username]) : nil,
      approver_pin: params[:approver_pin]
    )
    if result.success?
      redirect_to reconciliations_path, notice: "Reconciliation finalized."
    else
      redirect_back fallback_location: reconciliations_path, alert: result.error
    end
  end

  def record_resolution
    require_permission!("reporting.record_reconciliation_resolution")
    reconciliation = Current.store.reconciliations.find(params[:id])
    comparison = reconciliation.reconciliation_comparisons.find(params[:comparison_id])
    result = Reporting::RecordReconciliationResolution.call(
      reconciliation: reconciliation,
      actor: Current.user,
      reconciliation_comparison: comparison,
      resolution_type: params[:resolution_type].to_s,
      explanation: params[:explanation]
    )
    if result.success?
      redirect_back fallback_location: reconciliations_path, notice: "Resolution recorded."
    else
      redirect_back fallback_location: reconciliations_path, alert: result.error
    end
  end

  def accept_unavailable
    require_permission!("reporting.record_reconciliation_resolution")
    reconciliation = Current.store.reconciliations.find(params[:id])
    comparison = reconciliation.reconciliation_comparisons.find(params[:comparison_id])
    result = Reporting::RecordReconciliationResolution.call(
      reconciliation: reconciliation,
      actor: Current.user,
      reconciliation_comparison: comparison,
      resolution_type: "accept_evidence_unavailable",
      explanation: params[:explanation].presence || "Accepted unavailable evidence"
    )
    if result.success?
      redirect_back fallback_location: reconciliations_path, notice: "Unavailable evidence accepted."
    else
      redirect_back fallback_location: reconciliations_path, alert: result.error
    end
  end
end
