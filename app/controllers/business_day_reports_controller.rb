# frozen_string_literal: true

class BusinessDayReportsController < ApplicationController
  before_action :set_business_day

  def x
    require_permission!("reporting.view_business_day_x")
    @totals = Reporting::BuildBusinessDayTotals.call(business_day: @business_day, mode: :live)
    @show_cash = Current.user.can?("reporting.view_cash", store: Current.store)
    @show_cost = Current.user.can?("reporting.view_cost", store: Current.store)
    @show_margin = Current.user.can?("reporting.view_margin", store: Current.store)
  end

  def z
    require_permission!("reporting.view_business_day_z")
    @z_report = @business_day.business_day_z_report
    unless @z_report
      redirect_to business_days_path, alert: "No Business-Day Z report for this day."
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
      action: "business_day_z_report.viewed",
      subject: @z_report,
      metadata: { "z_number" => @z_report.z_number }
    )
  end

  private

  def set_business_day
    @business_day = Current.store.business_days.find(params[:id])
  end
end
