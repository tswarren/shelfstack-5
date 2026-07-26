# frozen_string_literal: true

require "test_helper"

module Customers
  class UpdateTest < ActiveSupport::TestCase
    setup do
      @customer = customers(:jordan_lee)
      @admin = users(:admin)
      @store = stores(:main_street)
    end

    test "updates contact fields" do
      result = Update.call(
        customer: @customer,
        actor: @admin,
        store: @store,
        attributes: { first_name: "Jordan", last_name: "Updated", city: "London" }
      )

      assert result.success?, result.error
      assert_equal "Updated", @customer.reload.last_name
      assert_equal "London", @customer.city
    end

    test "ignores customer_type and active even when submitted" do
      original_type = @customer.customer_type

      result = Update.call(
        customer: @customer,
        actor: @admin,
        store: @store,
        attributes: {
          first_name: "Jordan",
          last_name: "Lee",
          preferred_contact_method: "email",
          primary_email: @customer.primary_email,
          customer_type: "organization",
          active: false
        }
      )

      assert result.success?, result.error
      @customer.reload
      assert_equal original_type, @customer.customer_type
      assert @customer.active?
    end

    test "invalid phone preserves other attempted attributes for redisplay" do
      result = Update.call(
        customer: @customer,
        actor: @admin,
        store: @store,
        default_phone_country: "CA",
        attributes: {
          first_name: "Ada",
          last_name: "Lovelace",
          city: "Waterloo",
          primary_phone: "not-a-phone"
        }
      )

      assert_not result.success?
      assert_equal "Ada", result.customer.first_name
      assert_equal "Lovelace", result.customer.last_name
      assert_equal "Waterloo", result.customer.city
      assert_equal "not-a-phone", result.customer.primary_phone
      assert result.customer.errors[:primary_phone].any?

      @customer.reload
      assert_equal "Jordan", @customer.first_name
      assert_equal "+15195550123", @customer.primary_phone
    end
  end
end
