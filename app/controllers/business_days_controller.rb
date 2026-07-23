# frozen_string_literal: true

class BusinessDaysController < ApplicationController
  # Open/close forms are part of the operational register flow; history lists
  # stay on the back-office `application` layout (phase-04f-ux-baseline.md).
  layout -> { action_name.in?(%w[new create close close_form]) ? "pos" : "application" }

  before_action -> { require_permission!("pos.access") }, only: %i[index]
  before_action -> { require_permission!("pos.business_day.open") }, only: %i[new create]
  before_action -> { require_permission!("pos.business_day.close") }, only: %i[close close_form]
  before_action :set_business_day, only: %i[close close_form]

  def index
    @business_days = Current.store.business_days.order(opened_at: :desc)
  end

  def new
    @business_day = Current.store.business_days.new(reporting_date: StoreTime.today(Current.store))
  end

  def create
    result = Pos::OpenBusinessDay.call(
      store: Current.store,
      actor: Current.user,
      reporting_date: params.dig(:business_day, :reporting_date).presence
    )
    if result.success?
      redirect_to register_path, notice: "Business day opened."
    else
      @business_day = Current.store.business_days.new(reporting_date: StoreTime.today(Current.store))
      redirect_to new_business_day_path, alert: result.error
    end
  end

  def close_form
    @requires_card_evidence = day_has_card_tenders?(@business_day)
  end

  def close
    card_evidence = build_card_evidence_params if day_has_card_tenders?(@business_day)

    result = Pos::CloseBusinessDay.call(
      business_day: @business_day,
      actor: Current.user,
      card_evidence: card_evidence
    )
    if result.success?
      notice = result.replayed ? "Business day already closed." : "Business day closed."
      if result.business_day_z_report && Current.user.can?("reporting.view_business_day_z", store: Current.store)
        redirect_to business_day_z_report_business_day_path(@business_day), notice: notice
      else
        redirect_to register_path, notice: notice
      end
    else
      redirect_to close_form_business_day_path(@business_day), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to close_form_business_day_path(@business_day), alert: e.message
  end

  private

  def set_business_day
    @business_day = Current.store.business_days.find(params[:id])
  end

  def day_has_card_tenders?(business_day)
    PosTender
      .joins(:tender_type, pos_transaction: :completed_pos_session)
      .where(pos_sessions: { business_day_id: business_day.id }, pos_transactions: { status: "completed" })
      .where(status: "completed", removed_at: nil)
      .where(tender_types: { tender_category: "card" })
      .exists?
  end

  def build_card_evidence_params
    mode = params[:card_evidence_mode].presence || "recorded"
    if mode == "unavailable"
      {
        mode: "unavailable",
        unavailable_reason: params[:card_unavailable_reason]
      }
    else
      {
        mode: "recorded",
        net_cents: money_param_to_cents(params[:card_net_cents], label: "Batch net"),
        batch_reference: params[:card_batch_reference]
      }
    end
  end
end
