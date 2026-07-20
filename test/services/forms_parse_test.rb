# frozen_string_literal: true

require "test_helper"

class FormsParseTest < ActiveSupport::TestCase
  test "ParseMoney returns blank, ok, and invalid statuses" do
    assert Forms::ParseMoney.call("").blank?
    assert Forms::ParseMoney.call(nil).blank?

    ok = Forms::ParseMoney.call("$12.95")
    assert ok.ok?
    assert_equal 1295, ok.value

    bad = Forms::ParseMoney.call("abc")
    assert bad.invalid?
    assert_nil bad.value
    assert_equal "abc", bad.raw
  end

  test "ParsePercent always treats UI input as percentage points" do
    assert_equal 50, Forms::ParsePercent.to_bps("0.5").value
    assert_equal 50, Forms::ParsePercent.to_bps("0.5%").value
    assert_equal 15, Forms::ParsePercent.to_bps("0.15").value
    assert_equal 1500, Forms::ParsePercent.to_bps("15").value

    bad = Forms::ParsePercent.to_bps("nope")
    assert bad.invalid?
  end

  test "fraction_to_bps retains legacy 0-1 fraction behavior for non-UI callers" do
    assert_equal 5000, Forms::ParsePercent.fraction_to_bps("0.5").value
    assert_equal 50, Forms::ParsePercent.fraction_to_bps("0.5%").value
  end
end
