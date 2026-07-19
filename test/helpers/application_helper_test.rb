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
end
