# frozen_string_literal: true

require "test_helper"

module Pos
  class UnlinkedReturnRefundAmountTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @tax_category = tax_categories(:physical_book)
    end

    test "no_tax_refund yields merchandise only" do
      result = UnlinkedReturnRefundAmount.call(
        store: @store,
        quantity: 2,
        unit_price_cents: 500,
        tax_basis: "no_tax_refund",
        tax_category: @tax_category
      )
      assert result.success?, result.error
      assert_equal 1000, result.merchandise_cents
      assert_equal 0, result.tax_cents
      assert_equal 1000, result.total_cents
    end

    test "external_receipt_tax adds explicit tax" do
      result = UnlinkedReturnRefundAmount.call(
        store: @store,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "external_receipt_tax",
        tax_category: @tax_category,
        explicit_tax_amount_cents: 80
      )
      assert result.success?, result.error
      assert_equal 1000, result.merchandise_cents
      assert_equal 80, result.tax_cents
      assert_equal 1080, result.total_cents
    end

    test "current_configured_rules includes calculated return tax" do
      result = UnlinkedReturnRefundAmount.call(
        store: @store,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "current_configured_rules",
        tax_category: @tax_category
      )
      assert result.success?, result.error
      assert_equal 1000, result.merchandise_cents
      assert result.tax_cents.positive?
      assert_equal 1000 + result.tax_cents, result.total_cents
    end
  end
end
