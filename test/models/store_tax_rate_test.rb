# frozen_string_literal: true

require "test_helper"

class StoreTaxRateTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
  end

  test "requires a nonnegative rate" do
    rate = StoreTaxRate.new(store: @store, code: "NEG", name: "Negative", rate: -0.01)
    refute rate.valid?
    assert_includes rate.errors[:rate], "must be greater than or equal to 0"
  end

  test "code is unique within a store" do
    duplicate = StoreTaxRate.new(store: @store, code: store_tax_rates(:gst_13).code, name: "Dup", rate: 0.05)
    refute duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "effective_to must be on or after effective_from" do
    rate = StoreTaxRate.new(
      store: @store, code: "BAD", name: "Bad range", rate: 0.05,
      effective_from: Date.new(2027, 1, 1), effective_to: Date.new(2026, 1, 1)
    )
    refute rate.valid?
    assert_includes rate.errors[:effective_to], "must be on or after effective_from"
  end

  test "zero_rate? is true only for an explicit 0 rate" do
    assert store_tax_rates(:gst_zero).zero_rate?
    refute store_tax_rates(:gst_13).zero_rate?
  end
end
