# frozen_string_literal: true

class BusinessDayReportsController < ApplicationController
  before_action :set_business_day

  def x
    require_permission!("reporting.view_business_day_x")
    load_report_flags!
    load_sessions_index!
    @totals = Reporting::BuildBusinessDayTotals.call(business_day: @business_day, mode: :live)
  end

  def z
    require_permission!("reporting.view_business_day_z")
    @z_report = @business_day.business_day_z_report
    unless @z_report
      redirect_to business_days_path, alert: "No Business-Day Z report for this day."
      return
    end

    load_report_flags!
    load_sessions_index!
    @payload = @z_report.payload

    Administration::RecordAuditEvent.call(
      actor: Current.user,
      organization: Current.store.organization,
      store: Current.store,
      action: "business_day_z_report.viewed",
      subject: @z_report,
      metadata: { "z_number" => @z_report.z_number }
    )
  end

  private

  def set_business_day
    @business_day = Current.store.business_days.find(params[:id])
  end

  def load_report_flags!
    @show_cash = Current.user.can?("reporting.view_cash", store: Current.store)
    @show_cost = Current.user.can?("reporting.view_cost", store: Current.store)
    @show_margin = Current.user.can?("reporting.view_margin", store: Current.store)
  end

  def load_sessions_index!
    @sessions_by_id = @business_day.pos_sessions
      .includes(:pos_device, :cashier_user, :pos_session_z_report)
      .index_by(&:id)
  end
end
