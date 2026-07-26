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

  test "picker_label prefers alternate contact that matches the query" do
    customer = customers(:jordan_lee)
    customer.alternate_email = "school-office@example.org"
    customer.primary_email = "jordan.lee@example.com"

    label = customer.picker_label(query: "school-office")

    assert_match "school-office@example.org", label
    assert_no_match(/jordan\.lee@example\.com/, label)
  end
end
