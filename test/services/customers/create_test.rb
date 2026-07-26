# frozen_string_literal: true

require "test_helper"

module Customers
  class CreateTest < ActiveSupport::TestCase
    setup do
      IdentifierSequence.ensure_defaults!
      @organization = organizations(:acme)
      @store = stores(:main_street)
      @admin = users(:admin)
    end

    test "creates individual with namespace 22 customer_number" do
      result = Create.call(
        organization: @organization,
        actor: @admin,
        store: @store,
        attributes: {
          customer_type: "individual",
          first_name: "Ada",
          last_name: "Lovelace",
          preferred_contact_method: "none"
        }
      )

      assert result.success?, result.error
      assert result.customer.customer_number.start_with?("22")
      assert_equal 13, result.customer.customer_number.length
      assert_equal "Ada Lovelace", result.customer.display_name
    end

    test "normalizes phone with store country and rejects ambiguous values" do
      result = Create.call(
        organization: @organization,
        actor: @admin,
        store: @store,
        default_phone_country: "CA",
        attributes: {
          customer_type: "individual",
          first_name: "Phone",
          last_name: "Test",
          preferred_contact_method: "phone",
          primary_phone: "(519) 555-0199"
        }
      )

      assert result.success?, result.error
      assert_equal "+15195550199", result.customer.primary_phone
    end

    test "explicit plus country is not reinterpreted by store country" do
      result = Create.call(
        organization: @organization,
        actor: @admin,
        store: @store,
        default_phone_country: "CA",
        attributes: {
          customer_type: "individual",
          first_name: "UK",
          last_name: "Number",
          preferred_contact_method: "phone",
          primary_phone: "+442079460018"
        }
      )

      assert result.success?, result.error
      assert_equal "+442079460018", result.customer.primary_phone
    end

    test "returns possible duplicates before insert" do
      result = Create.call(
        organization: @organization,
        actor: @admin,
        store: @store,
        attributes: {
          customer_type: "individual",
          first_name: "Other",
          last_name: "Jordan",
          preferred_contact_method: "email",
          primary_email: "jordan.lee@example.com"
        }
      )

      assert_not result.success?
      assert_equal "possible_duplicates", result.error
      assert_includes result.possible_duplicates.map(&:id), customers(:jordan_lee).id
      assert_equal 0, Customer.where(first_name: "Other", last_name: "Jordan").count
    end

    test "create_anyway persists despite duplicates" do
      result = Create.call(
        organization: @organization,
        actor: @admin,
        store: @store,
        create_anyway: true,
        attributes: {
          customer_type: "individual",
          first_name: "Other",
          last_name: "Jordan",
          preferred_contact_method: "email",
          primary_email: "jordan.lee@example.com"
        }
      )

      assert result.success?, result.error
      assert_equal "jordan.lee@example.com", result.customer.primary_email
    end
  end
end
