# frozen_string_literal: true

require "test_helper"

class CountryCodeTest < ActiveSupport::TestCase
  test "options_for_select uses display names and preserves unknown codes" do
    options = CountryCode.options_for_select(selected: "ZZ")

    assert_includes options, [ "Canada", "CA" ]
    assert_includes options, [ "United States", "US" ]
    assert_includes options, [ "ZZ", "ZZ" ]
    assert_equal "Canada", CountryCode.name_for("ca")
  end
end
