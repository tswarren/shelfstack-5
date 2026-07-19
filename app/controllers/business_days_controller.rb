# frozen_string_literal: true

class BusinessDaysController < ApplicationController
  # Open/close forms are part of the operational register flow; history lists
  # stay on the back-office `application` layout (phase-04f-ux-baseline.md).
  layout -> { action_name.in?(%w[new create close]) ? "pos" : "application" }

  before_action -> { require_permission!("pos.access") }, only: %i[index]
  before_action -> { require_permission!("pos.business_day.open") }, only: %i[new create]
  before_action -> { require_permission!("pos.business_day.close") }, only: %i[close]
  before_action :set_business_day, only: %i[close]

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

  def close
    result = Pos::CloseBusinessDay.call(business_day: @business_day, actor: Current.user)
    if result.success?
      redirect_to register_path, notice: result.replayed ? "Business day already closed." : "Business day closed."
    else
      redirect_to register_path, alert: result.error
    end
  end

  private

  def set_business_day
    @business_day = Current.store.business_days.find(params[:id])
  end
end
