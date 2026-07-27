# frozen_string_literal: true

require "test_helper"

module Pos
  class ProductLookupResultsTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @variant = product_variants(:sample_book_standard)
    end

    test "groups variants with price availability and eligibility" do
      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 4, reserved: 1, unavailable: 0,
        inventory_value_cents: 2000, moving_average_cost_cents: 500, cost_quality: "actual"
      )

      result = ProductLookupResults.call(
        organization: @store.organization,
        store: @store,
        query: @variant.sku
      )

      assert_equal 1, result.groups.size
      row = result.groups.first.variants.first
      assert_equal @variant.id, row.product_variant_id
      assert_equal @variant.regular_price_cents, row.price_cents
      assert_equal 3, row.available_quantity
      assert row.addable?
      assert_includes ProductLookupResults.as_scan_candidates(result).first["variants"].first.keys, "addable"
    end
  end
end
