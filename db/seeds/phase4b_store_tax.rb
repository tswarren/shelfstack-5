# frozen_string_literal: true

# Demo Store Tax Rates/Rules for bootstrap stores.
# Governed by ADR-0014 and docs/implementation/phase-04-tax-schema.md.
#
# Two non-compounding components:
#   STATE6  — State Sales Tax @ 6.00%
#   FOOD125 — Food/Beverage Tax @ 1.25%
#
# Every active Tax Category receives an explicit rule for EACH component
# (taxable / exempt / not_applicable). Missing rules remain completion blockers.
#
# Idempotent upsert of the demo matrix. Deactivates retired demo rates/rules
# (GST13, legacy state_sales_tax) so re-runs leave only STATE6 + FOOD125 active.

organization = Organization.first
raise "No organization found; run bin/rails shelfstack:bootstrap first" unless organization

STATE_CODE = "STATE6"
STATE_NAME = "State Sales Tax"
STATE_RATE = BigDecimal("0.06000000")
STATE_RECEIPT = "S"
STATE_ORDER = 0

FOOD_CODE = "FOOD125"
FOOD_NAME = "Food/Beverage Tax"
FOOD_RATE = BigDecimal("0.01250000")
FOOD_RECEIPT = "F"
FOOD_ORDER = 1

# [tax_category_code, state_treatment, food_treatment]
# Treatments: taxable | exempt | not_applicable (zero_rated unused in this US-style demo)
DEMO_TAX_MATRIX = [
  [ "physical_gen_merchandise", "taxable", "not_applicable" ],
  [ "physical_audio", "taxable", "not_applicable" ],
  [ "physical_book", "taxable", "not_applicable" ],
  [ "physical_clothing", "taxable", "not_applicable" ],
  [ "physical_newspaper", "exempt", "not_applicable" ],
  [ "physical_periodical", "exempt", "not_applicable" ],
  [ "physical_video", "taxable", "not_applicable" ],
  [ "food_beverage_bakery", "taxable", "taxable" ],
  [ "food_beverage_bottled_soft_drink", "taxable", "exempt" ],
  [ "food_beverage_bottled_water", "taxable", "exempt" ],
  [ "food_beverage_grocery", "exempt", "exempt" ],
  [ "food_beverage_packaged_food", "taxable", "exempt" ],
  [ "food_beverage_prepared_food", "taxable", "taxable" ],
  [ "digital_audio", "exempt", "not_applicable" ],
  [ "digital_book", "exempt", "not_applicable" ],
  [ "digital_video", "exempt", "not_applicable" ],
  [ "intangible_delivery", "exempt", "not_applicable" ],
  [ "intangible_membership_fees", "exempt", "not_applicable" ],
  [ "intangible_service_fees", "exempt", "not_applicable" ],
  [ "other_admission", "exempt", "not_applicable" ]
].freeze

RETIRED_DEMO_RATE_CODES = %w[GST13 state_sales_tax].freeze
ACTIVE_DEMO_COMPONENT_CODES = [ STATE_CODE, FOOD_CODE ].freeze

def upsert_demo_rate!(store:, code:, name:, rate:, receipt_code:)
  record = store.store_tax_rates.find_or_initialize_by(code: code)
  record.assign_attributes(
    name: name,
    receipt_code: receipt_code,
    rate: rate,
    active: true
  )
  record.save!
  record
end

def upsert_demo_rule!(store:, tax_category:, rate:, component_code:, treatment:, calculation_order:)
  rule = store.store_tax_rules.find_or_initialize_by(
    tax_category: tax_category,
    component_code: component_code
  )

  collecting = %w[taxable zero_rated].include?(treatment)
  rule.assign_attributes(
    store_tax_rate: collecting ? rate : nil,
    treatment: treatment,
    taxable_fraction: collecting ? BigDecimal("1") : BigDecimal("0"),
    calculation_order: calculation_order,
    compounds_on_prior_tax: false,
    active: true
  )
  rule.save!
  rule
end

def retire_non_demo_tax_components!(store)
  RETIRED_DEMO_RATE_CODES.each do |code|
    retired = store.store_tax_rates.find_by(code: code)
    next unless retired

    store.store_tax_rules.where(store_tax_rate_id: retired.id)
                         .or(store.store_tax_rules.where(component_code: code))
                         .update_all(active: false)
    retired.update!(active: false)
  end

  # Safety net: any leftover active component that is not part of the demo matrix.
  store.store_tax_rules
       .where(active: true)
       .where.not(component_code: ACTIVE_DEMO_COMPONENT_CODES)
       .update_all(active: false)

  store.store_tax_rates
       .where(active: true)
       .where.not(code: ACTIVE_DEMO_COMPONENT_CODES)
       .update_all(active: false)
end

organization.stores.find_each do |store|
  state_rate = upsert_demo_rate!(
    store: store, code: STATE_CODE, name: STATE_NAME, rate: STATE_RATE, receipt_code: STATE_RECEIPT
  )
  food_rate = upsert_demo_rate!(
    store: store, code: FOOD_CODE, name: FOOD_NAME, rate: FOOD_RATE, receipt_code: FOOD_RECEIPT
  )

  retire_non_demo_tax_components!(store)

  DEMO_TAX_MATRIX.each do |category_code, state_treatment, food_treatment|
    tax_category = organization.tax_categories.find_by(code: category_code, active: true)
    next unless tax_category

    upsert_demo_rule!(
      store: store,
      tax_category: tax_category,
      rate: state_rate,
      component_code: STATE_CODE,
      treatment: state_treatment,
      calculation_order: STATE_ORDER
    )
    upsert_demo_rule!(
      store: store,
      tax_category: tax_category,
      rate: food_rate,
      component_code: FOOD_CODE,
      treatment: food_treatment,
      calculation_order: FOOD_ORDER
    )
  end

  # Any other active tax categories (future CSV rows) get fail-closed defaults:
  # state taxable + food not_applicable, so completion is not blocked.
  covered = DEMO_TAX_MATRIX.map(&:first)
  organization.tax_categories.where(active: true).where.not(code: covered).find_each do |tax_category|
    upsert_demo_rule!(
      store: store,
      tax_category: tax_category,
      rate: state_rate,
      component_code: STATE_CODE,
      treatment: "taxable",
      calculation_order: STATE_ORDER
    )
    upsert_demo_rule!(
      store: store,
      tax_category: tax_category,
      rate: food_rate,
      component_code: FOOD_CODE,
      treatment: "not_applicable",
      calculation_order: FOOD_ORDER
    )
  end
end

puts "Phase 4b store tax demo seed complete for organization=#{organization.code} " \
     "(#{STATE_CODE} @ #{STATE_RATE}; #{FOOD_CODE} @ #{FOOD_RATE}; per-category treatment matrix)"
