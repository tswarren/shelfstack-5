# frozen_string_literal: true

require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "picker_label includes phone email and city when present" do
    customer = customers(:jordan_lee)
    customer.city = "London"

    assert_equal(
      "Jordan Lee · #{customer.customer_number} · #{customer.primary_phone} · #{customer.primary_email} · London",
      customer.picker_label
    )
  end

  test "picker_label omits blank reference fields" do
    customer = customers(:inactive_patron)

    assert_equal "Inactive Patron · #{customer.customer_number}", customer.picker_label
  end
end
