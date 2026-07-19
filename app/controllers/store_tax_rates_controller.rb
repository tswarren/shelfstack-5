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
    attrs = store_tax_rate_params
    @store_tax_rate = Current.store.store_tax_rates.new(attrs)
    copy_human_readable_param_errors!(@store_tax_rate)

    if @store_tax_rate.errors.any? || !Classification::CreateStoreTaxRate.call(
      store_tax_rate: @store_tax_rate,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      render :new, status: :unprocessable_entity
    else
      redirect_to store_tax_rates_path, notice: "Store tax rate created."
    end
  end

  def edit
  end

  def update
    attrs = store_tax_rate_params.to_h
    if human_readable_params_invalid?
      copy_human_readable_param_errors!(@store_tax_rate)
      render :edit, status: :unprocessable_entity
      return
    end

    if Classification::UpdateStoreTaxRate.call(
      store_tax_rate: @store_tax_rate,
      attributes: attrs,
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
    if raw.key?(:rate_percent)
      write_parsed_attr!(attrs, :rate, parse_percent_rate_param(raw[:rate_percent]))
    end

    attrs
  end
end
