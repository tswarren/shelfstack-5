# frozen_string_literal: true

class StoreTaxRulesController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index]
  before_action -> { require_permission!("classification.store_tax_rule.manage") }, only: %i[new create edit update]
  before_action :set_store_tax_rule, only: %i[edit update]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @store_tax_rules = Current.store.store_tax_rules.includes(:tax_category, :store_tax_rate)
                               .joins(:tax_category)
                               .order("tax_categories.name", :calculation_order, :component_code)
  end

  def new
    @store_tax_rule = Current.store.store_tax_rules.new(active: true, taxable_fraction: 1, calculation_order: 0,
                                                          compounds_on_prior_tax: false)
  end

  def create
    attrs = store_tax_rule_params
    @store_tax_rule = Current.store.store_tax_rules.new(attrs)
    copy_human_readable_param_errors!(@store_tax_rule)

    if @store_tax_rule.errors.any? || !Classification::CreateStoreTaxRule.call(
      store_tax_rule: @store_tax_rule,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      render :new, status: :unprocessable_entity
    else
      redirect_to store_tax_rules_path, notice: "Store tax rule created."
    end
  end

  def edit
  end

  def update
    attrs = store_tax_rule_params.to_h
    if human_readable_params_invalid?
      copy_human_readable_param_errors!(@store_tax_rule)
      render :edit, status: :unprocessable_entity
      return
    end

    if Classification::UpdateStoreTaxRule.call(
      store_tax_rule: @store_tax_rule,
      attributes: attrs,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to store_tax_rules_path, notice: "Store tax rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_store_tax_rule
    @store_tax_rule = Current.store.store_tax_rules.find(params[:id])
  end

  def load_form_collections
    @tax_categories = Current.organization.tax_categories.order(:code)
    @store_tax_rates = Current.store.store_tax_rates.order(:code)
  end

  def store_tax_rule_params
    attrs = params.require(:store_tax_rule).permit(
      :tax_category_id, :store_tax_rate_id, :component_code, :treatment, :taxable_fraction,
      :calculation_order, :compounds_on_prior_tax, :effective_from, :effective_to, :active
    )

    # The taxable portion is entered as a percentage in the UI and converted to the
    # domain's decimal-fraction storage. Direct `taxable_fraction` input (API/tests)
    # still works when the percent field is absent.
    raw = params[:store_tax_rule] || {}
    if raw.key?(:taxable_fraction_percent)
      write_parsed_attr!(
        attrs, :taxable_fraction, parse_percent_rate_param(raw[:taxable_fraction_percent])
      )
    end

    attrs
  end
end
