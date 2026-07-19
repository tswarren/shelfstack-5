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

  test "parse_percent_to_bps handles percent and fraction forms" do
    assert_equal 1500, parse_percent_to_bps("15%")
    assert_equal 1500, parse_percent_to_bps("15")
    assert_equal 1500, parse_percent_to_bps("0.15")
  end
end
