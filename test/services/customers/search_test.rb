# frozen_string_literal: true

require "test_helper"

module Customers
  class SearchTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:acme)
      @customer = customers(:jordan_lee)
    end

    test "finds customers by common phone formats using store country" do
      [
        "(519) 555-0123",
        "519-555-0123",
        "+1 519-555-0123"
      ].each do |query|
        result = Search.call(
          organization: @organization,
          query: query,
          default_phone_country: "CA"
        )
        assert_includes result.customers.map(&:id), @customer.id, "expected match for #{query.inspect}"
      end
    end

    test "still finds by name when phone normalize fails" do
      result = Search.call(
        organization: @organization,
        query: "Jordan",
        default_phone_country: "CA"
      )

      assert_includes result.customers.map(&:id), @customer.id
    end

    test "finds customers by city" do
      @customer.update!(city: "Waterloo")

      result = Search.call(organization: @organization, query: "Waterloo")

      assert_includes result.customers.map(&:id), @customer.id
    end
  end
end
