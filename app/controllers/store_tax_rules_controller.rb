# frozen_string_literal: true

class StoreTaxRulesController < ApplicationController
  before_action -> { require_permission!("classification.view") }, only: %i[index]
  before_action -> { require_permission!("classification.store_tax_rule.manage") }, only: %i[new create edit update]
  before_action :set_store_tax_rule, only: %i[edit update]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @store_tax_rules = Current.store.store_tax_rules.includes(:tax_category, :store_tax_rate)
                               .order(:calculation_order, :component_code)
  end

  def new
    @store_tax_rule = Current.store.store_tax_rules.new(active: true, taxable_fraction: 1, calculation_order: 0,
                                                          compounds_on_prior_tax: false)
  end

  def create
    @store_tax_rule = Current.store.store_tax_rules.new(store_tax_rule_params)
    if Classification::CreateStoreTaxRule.call(
      store_tax_rule: @store_tax_rule,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to store_tax_rules_path, notice: "Store tax rule created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Classification::UpdateStoreTaxRule.call(
      store_tax_rule: @store_tax_rule,
      attributes: store_tax_rule_params.to_h,
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
    params.require(:store_tax_rule).permit(
      :tax_category_id, :store_tax_rate_id, :component_code, :treatment, :taxable_fraction,
      :calculation_order, :compounds_on_prior_tax, :effective_from, :effective_to, :active
    )
  end
end
