# frozen_string_literal: true

class StoreTaxRatesController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index]
  before_action -> { require_permission!("classification.store_tax_rule.manage") }, only: %i[new create edit update]
  before_action :set_store_tax_rate, only: %i[edit update]

  def index
    @store_tax_rates = Current.store.store_tax_rates.order(:code)
  end

  def new
    @store_tax_rate = Current.store.store_tax_rates.new(active: true)
  end

  def create
    @store_tax_rate = Current.store.store_tax_rates.new(store_tax_rate_params)
    if Classification::CreateStoreTaxRate.call(
      store_tax_rate: @store_tax_rate,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to store_tax_rates_path, notice: "Store tax rate created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateStoreTaxRate.call(
      store_tax_rate: @store_tax_rate,
      attributes: store_tax_rate_params.to_h,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to store_tax_rates_path, notice: "Store tax rate updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_store_tax_rate
    @store_tax_rate = Current.store.store_tax_rates.find(params[:id])
  end

  def store_tax_rate_params
    attrs = params.require(:store_tax_rate).permit(
      :code, :name, :receipt_code, :jurisdiction_name, :rate, :effective_from, :effective_to, :active
    )

    # The rate is entered as a percentage in the UI and converted to the domain's
    # decimal-fraction storage. Direct `rate` input (API/tests) still works when
    # the percent field is absent.
    raw = params[:store_tax_rate] || {}
    attrs[:rate] = helpers.parse_percent_to_rate(raw[:rate_percent]) if raw.key?(:rate_percent)

    attrs
  end
end
