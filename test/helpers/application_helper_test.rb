# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "parse_money_to_cents accepts dollars and currency symbols" do
    assert_equal 1295, parse_money_to_cents("12.95")
    assert_equal 1295, parse_money_to_cents("$12.95")
    assert_equal 1200, parse_money_to_cents("12")
    assert_nil parse_money_to_cents("")
    assert_nil parse_money_to_cents("abc")
  end

  test "parse_percent_to_bps always treats input as percentage points" do
    assert_equal 1500, parse_percent_to_bps("15%")
    assert_equal 1500, parse_percent_to_bps("15")
    assert_equal 15, parse_percent_to_bps("0.15")
    assert_equal 50, parse_percent_to_bps("0.5")
  end

  test "0.5 percent round-trips through format and parse unchanged" do
    stored_bps = 50 # 0.5%
    displayed = format_bps_as_percent(stored_bps)
    assert_equal "0.5%", displayed
    assert_equal stored_bps, parse_percent_to_bps(displayed)
    assert_equal stored_bps, parse_percent_to_bps(displayed.delete("%"))
  end

  test "variant_option_label includes product, variant, and SKU" do
    variant = product_variants(:sample_book_standard)
    label = variant_option_label(variant)

    assert_includes label, variant.product.name
    assert_includes label, variant.name
    assert_includes label, variant.sku
  end

  test "hierarchy_path_label walks department parents" do
    child = departments(:books_new)
    label = hierarchy_path_label(child)

    assert_includes label, child.name
    assert_includes label, "›" if child.parent_department.present?
  end

  test "record_option_label is name-first with code secondary" do
    rate = store_tax_rates(:gst_13)
    label = record_option_label(rate)

    assert label.start_with?(rate.name)
    assert_includes label, rate.code
  end

  test "hierarchy_path_label omits merchandise class codes" do
    mc = merchandise_classes(:fiction_primary)
    label = hierarchy_path_label(mc)

    assert_includes label, mc.name
    refute_includes label, mc.code
  end

  test "tax_treatment_label humanizes known treatments" do
    assert_equal "Zero-rated", tax_treatment_label("zero_rated")
    assert_equal "Not applicable", tax_treatment_label("not_applicable")
  end
end
