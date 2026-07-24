# frozen_string_literal: true

class SessionReportsController < ApplicationController
  before_action :set_session

  def x
    require_permission!("reporting.view_session_x")
    @totals = Reporting::BuildSessionTotals.call(pos_session: @session)
    @show_cash = Current.user.can?("reporting.view_cash", store: Current.store)
    @show_cost = Current.user.can?("reporting.view_cost", store: Current.store)
    @show_margin = Current.user.can?("reporting.view_margin", store: Current.store)
  end

  def z
    require_permission!("reporting.view_session_z")
    @z_report = @session.pos_session_z_report
    unless @z_report
      redirect_to register_path, alert: "No Session Z report for this session."
      return
    end

    @payload = @z_report.payload
    @show_cash = Current.user.can?("reporting.view_cash", store: Current.store)
    @show_cost = Current.user.can?("reporting.view_cost", store: Current.store)
    @show_margin = Current.user.can?("reporting.view_margin", store: Current.store)

    Administration::RecordAuditEvent.call(
      actor: Current.user,
      organization: Current.store.organization,
      store: Current.store,
      action: "pos_session_z_report.viewed",
      subject: @z_report,
      metadata: { "z_number" => @z_report.z_number }
    )
  end

  private

  def set_session
    @session = Current.store.pos_sessions.find(params[:id])
  end
end
