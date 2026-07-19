# frozen_string_literal: true

require "test_helper"

class StoreTaxRuleTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @gst_13 = store_tax_rates(:gst_13)
    @gst_zero = store_tax_rates(:gst_zero)
    @tax_category = tax_categories(:unconfigured_category)
  end

  def valid_attributes(overrides = {})
    {
      store: @store, tax_category: @tax_category, store_tax_rate: @gst_13, component_code: "GST13",
      treatment: "taxable", taxable_fraction: 1, calculation_order: 0, compounds_on_prior_tax: false, active: true
    }.merge(overrides)
  end

  test "valid taxable rule" do
    rule = StoreTaxRule.new(valid_attributes)
    assert rule.valid?
  end

  test "taxable treatment requires a store tax rate" do
    rule = StoreTaxRule.new(valid_attributes(store_tax_rate: nil))
    refute rule.valid?
    assert_includes rule.errors[:store_tax_rate], "is required for taxable treatment"
  end

  test "zero_rated treatment requires an explicit 0% rate" do
    rule = StoreTaxRule.new(valid_attributes(treatment: "zero_rated", store_tax_rate: @gst_13, component_code: "GST13"))
    refute rule.valid?
    assert_includes rule.errors[:store_tax_rate], "must reference an explicit 0% rate for zero_rated treatment"
  end

  test "zero_rated treatment accepts an explicit 0% rate" do
    rule = StoreTaxRule.new(valid_attributes(treatment: "zero_rated", store_tax_rate: @gst_zero, component_code: "GST0"))
    assert rule.valid?
  end

  test "exempt treatment may omit the store tax rate" do
    rule = StoreTaxRule.new(valid_attributes(treatment: "exempt", store_tax_rate: nil, component_code: "EXEMPT"))
    assert rule.valid?
  end

  test "not_applicable treatment may omit the store tax rate" do
    rule = StoreTaxRule.new(
      valid_attributes(treatment: "not_applicable", store_tax_rate: nil, component_code: "FOOD125", taxable_fraction: 0)
    )
    assert rule.valid?
  end

  test "component_code must equal the referenced rate's code" do
    rule = StoreTaxRule.new(valid_attributes(component_code: "WRONG"))
    refute rule.valid?
    assert_includes rule.errors[:component_code], "must equal the referenced store tax rate's code"
  end

  test "rejects overlapping effective periods for the same store, tax category, and component" do
    StoreTaxRule.create!(valid_attributes(effective_from: nil, effective_to: nil))

    overlapping = StoreTaxRule.new(valid_attributes(effective_from: Date.new(2027, 1, 1)))
    refute overlapping.valid?
    assert_includes overlapping.errors[:base],
      "effective period overlaps another active store tax rule for the same store, tax category, and component code"
  end

  test "allows adjacent non-overlapping effective periods" do
    StoreTaxRule.create!(valid_attributes(effective_from: nil, effective_to: Date.new(2026, 12, 31)))

    later = StoreTaxRule.new(valid_attributes(effective_from: Date.new(2027, 1, 1), effective_to: nil))
    assert later.valid?
  end

  test "does not overlap with an inactive rule covering the same period" do
    StoreTaxRule.create!(valid_attributes(active: false))

    rule = StoreTaxRule.new(valid_attributes)
    assert rule.valid?
  end

  test "requires consistent calculation_order and compounding for rules sharing a rate" do
    other_category = TaxCategory.create!(
      organization: @store.organization, code: "consistency_check", name: "Consistency Check", active: true
    )
    StoreTaxRule.create!(valid_attributes)

    inconsistent = StoreTaxRule.new(valid_attributes(tax_category: other_category, calculation_order: 1))
    refute inconsistent.valid?
    assert_includes inconsistent.errors[:base],
      "calculation_order and compounds_on_prior_tax must be consistent for all rules sharing the same store tax rate"
  end

  test "taxable_fraction must be between 0 and 1" do
    rule = StoreTaxRule.new(valid_attributes(taxable_fraction: 1.5))
    refute rule.valid?
    assert_includes rule.errors[:taxable_fraction], "must be less than or equal to 1"
  end
end
