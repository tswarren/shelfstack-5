# frozen_string_literal: true

require "test_helper"

class CustomersNormalizePhoneTest < ActiveSupport::TestCase
  test "parses E.164 and national numbers with default country" do
    assert_equal "+15195550123", Customers::NormalizePhone.call("+1 519 555 0123")
    assert_equal "+15195550123", Customers::NormalizePhone.call("519-555-0123", default_country: "CA")
  end

  test "does not reinterpret a leading plus with store country" do
    assert_equal "+442071838750",
      Customers::NormalizePhone.call("+44 20 7183 8750", default_country: "CA")
  end

  test "raises a remedial error for invalid input" do
    error = assert_raises(Customers::NormalizePhone::Error) do
      Customers::NormalizePhone.call("not-a-phone", default_country: "CA")
    end
    assert_match(/valid phone number/i, error.message)
  end
end
