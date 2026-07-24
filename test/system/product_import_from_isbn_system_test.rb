# frozen_string_literal: true

require "application_system_test_case"

# ISBN import is a multi-step form flow without client-side JS requirements.
# rack_test keeps the app in-process so Catalog::Providers.transport_override
# is visible (Selenium's server thread otherwise risks real provider calls).
class ProductImportFromIsbnSystemTest < ApplicationSystemTestCase
  driven_by :rack_test

  CANONICAL_ISBN13 = "9780316769488"

  setup do
    IdentifierSequence.ensure_defaults!
    @previous_api_key = ENV["SHELFSTACK_ISBNDB_API_KEY"]
    ENV["SHELFSTACK_ISBNDB_API_KEY"] = "test-key"
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"
  end

  teardown do
    Catalog::Providers.transport_override = nil
    ENV["SHELFSTACK_ISBNDB_API_KEY"] = @previous_api_key
  end

  test "happy path creates a product from ISBN preview and opens the product" do
    visit new_product_import_path
    assert_text "Create from ISBN"

    fill_in "ISBN", with: CANONICAL_ISBN13
    select "ISBNdb", from: "Provider"
    click_button "Look up ISBN"

    assert_text "Preview product import"
    assert_field "Title", with: "Test Harbor"
    assert_text "external list price"

    click_button "Create product"

    assert_text "Product created from external metadata"
    assert_text "Test Harbor" # product show uses plain text title
    product = Product.find_by!(identifier: CANONICAL_ISBN13)
    assert_current_path product_path(product)
  end

  test "existing ISBN redirects to the product without creating another" do
    existing = products(:sample_book)
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [])

    visit new_product_import_path
    fill_in "ISBN", with: existing.identifier
    click_button "Look up ISBN"

    assert_text existing.name
    assert_current_path product_path(existing)
    assert_text(/already exists/i)
  end

  test "Product Request return_to lands on the request form with product selected after ISBN accept" do
    visit new_product_request_path
    click_link "Search or create it"

    assert_text "Create from ISBN"
    fill_in "ISBN", with: CANONICAL_ISBN13
    select "ISBNdb", from: "Provider"
    click_button "Look up ISBN"

    assert_text "Preview product import"
    click_button "Create product"

    product = Product.find_by!(identifier: CANONICAL_ISBN13)
    assert_current_path new_product_request_path(product_id: product.id)
    assert_equal product.id.to_s, find("#product_request_product_id", visible: :all).value
  end
end
