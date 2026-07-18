# frozen_string_literal: true

# Demo Store Tax Rate/Rule data for the bootstrap store(s), suitable for exercising Phase 4b
# tax calculation (Tax::CalculateTransaction) once wired into POS. Governed by ADR-0014 and
# docs/implementation/phase-04-tax-schema.md.
#
# Idempotent: safe to re-run. Never overwrites an existing Store Tax Rate/Rule; only fills in
# missing demo rows for stores/tax categories that do not yet have one.
#
# Invoked by: bin/rails shelfstack:seed_reference_data (after Classification::Import::ReferenceData)

organization = Organization.first
raise "No organization found; run bin/rails shelfstack:bootstrap first" unless organization

DEMO_STORE_TAX_RATE_CODE = "GST13"
DEMO_STORE_TAX_RATE_NAME = "GST 13% (demo)"
DEMO_STORE_TAX_RATE_VALUE = BigDecimal("0.13000000")
DEMO_RECEIPT_CODE = "G"

organization.stores.find_each do |store|
  rate = store.store_tax_rates.find_or_initialize_by(code: DEMO_STORE_TAX_RATE_CODE)
  if rate.new_record?
    rate.assign_attributes(
      name: DEMO_STORE_TAX_RATE_NAME,
      receipt_code: DEMO_RECEIPT_CODE,
      rate: DEMO_STORE_TAX_RATE_VALUE,
      active: true
    )
    rate.save!
  end

  organization.tax_categories.where(active: true).find_each do |tax_category|
    next if store.store_tax_rules.exists?(tax_category: tax_category, component_code: rate.code)

    store.store_tax_rules.create!(
      tax_category: tax_category,
      store_tax_rate: rate,
      component_code: rate.code,
      treatment: "taxable",
      taxable_fraction: 1,
      calculation_order: 0,
      compounds_on_prior_tax: false,
      active: true
    )
  end
end

puts "Phase 4b store tax demo seed complete for organization=#{organization.code} " \
     "(#{DEMO_STORE_TAX_RATE_CODE} @ #{DEMO_STORE_TAX_RATE_VALUE} for each store; taxable rules for active tax categories)"
