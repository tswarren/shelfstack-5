# frozen_string_literal: true

require "test_helper"

class CatalogResolveRecordPickerSelectionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "resolves an in-organization creator by id" do
    creator = creators(:ray_bradbury)

    result = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization, record_type: "creator", id: creator.id
    )

    assert_equal creator, result
  end

  test "resolves an inactive creator so linked products keep showing it" do
    creator = creators(:inactive_creator)

    result = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization, record_type: "creator", id: creator.id
    )

    assert_equal creator, result
  end

  test "returns nil for a foreign-organization creator id" do
    foreign = create_foreign_organization_catalog!

    result = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization, record_type: "creator", id: foreign[:creator].id
    )

    assert_nil result
  end

  test "returns nil for a blank id" do
    result = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization, record_type: "creator", id: nil
    )

    assert_nil result
  end

  test "resolves an in-organization customer by id" do
    customer = customers(:jordan_lee)

    result = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization, record_type: "customer", id: customer.id
    )

    assert_equal customer, result
  end

  test "resolves an inactive customer so linked forms keep showing it" do
    customer = customers(:inactive_patron)

    result = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization, record_type: "customer", id: customer.id
    )

    assert_equal customer, result
  end

  test "returns nil for a foreign-organization customer id" do
    foreign = create_foreign_organization_catalog!
    foreign_customer = Customer.create!(
      organization: foreign[:organization],
      customer_number: "2299999999992",
      customer_type: "individual",
      first_name: "Foreign",
      last_name: "Patron",
      preferred_contact_method: "none",
      active: true
    )

    result = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization, record_type: "customer", id: foreign_customer.id
    )

    assert_nil result
  end
end
