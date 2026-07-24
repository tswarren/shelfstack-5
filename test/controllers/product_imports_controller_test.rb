# frozen_string_literal: true

require "test_helper"

class ProductImportsControllerTest < ActionDispatch::IntegrationTest
  CANONICAL_ISBN13 = "9780316769488"

  setup do
    IdentifierSequence.ensure_defaults!
    @previous_api_key = ENV["SHELFSTACK_ISBNDB_API_KEY"]
    ENV["SHELFSTACK_ISBNDB_API_KEY"] = "test-key"
    @organization = organizations(:acme)
    @actor = users(:admin)
    @retrieved_at = Time.zone.parse("2026-07-24 12:00:00")
    post session_path, params: { username: "admin", password: "password123" }
  end

  teardown do
    Catalog::Providers.transport_override = nil
    ENV["SHELFSTACK_ISBNDB_API_KEY"] = @previous_api_key
  end

  test "creates a product from structured attributes and redirects to the new product request form" do
    assert_difference "Product.count", 1 do
      post product_imports_path, params: {
        product: {
          name: "Imported Via Thin Path", product_type: "book",
          product_format_id: product_formats(:hardcover).id
        },
        return_to: new_product_request_path
      }
    end

    product = Product.order(:id).last
    assert_redirected_to new_product_request_path(product_id: product.id)
  end

  test "surfaces duplicate candidates instead of creating a second product" do
    existing = products(:upc_product)

    assert_no_difference "Product.count" do
      post product_imports_path, params: {
        product: { identifier: existing.identifier, name: "Duplicate Attempt", product_type: "book" }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/possible duplicate/i, response.body)
  end

  test "denies clerk without catalog.product.create on thin create" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get new_product_import_path
    assert_redirected_to root_path
  end

  test "ISBN preview renders proposed fields without creating a product" do
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    assert_no_difference [ "Product.count", "CatalogEnrichmentEvent.count" ] do
      post preview_product_imports_path, params: {
        identifier: CANONICAL_ISBN13, provider: "isbndb"
      }, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_match(/Preview product import/i, response.body)
    assert_match(/Test Harbor/, response.body)
    assert_match(/external list price/i, response.body)
    assert_match(/name="preview_token"/, response.body)
  end

  test "existing ISBN redirects to the product show page" do
    existing = products(:sample_book)
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [])

    post preview_product_imports_path, params: {
      identifier: existing.identifier, provider: "isbndb"
    }

    assert_redirected_to product_path(existing)
    assert_match(/already exists/i, flash[:notice])
  end

  test "existing ISBN with return_to redirects to the product request form" do
    existing = products(:sample_book)
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [])

    post preview_product_imports_path, params: {
      identifier: existing.identifier,
      provider: "isbndb",
      return_to: new_product_request_path
    }

    assert_redirected_to new_product_request_path(product_id: existing.id)
  end

  test "provider error flashes and creates no product" do
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 404, fixture: "catalog/providers/isbndb_missing_book.json")
    ])

    assert_no_difference "Product.count" do
      post preview_product_imports_path, params: {
        identifier: CANONICAL_ISBN13, provider: "isbndb"
      }
    end

    assert_response :unprocessable_entity
    assert_match(/no isbndb record was found|not found|failed/i, response.body)
  end

  test "unknown provider returns unprocessable without creating a product" do
    assert_no_difference "Product.count" do
      post preview_product_imports_path, params: {
        identifier: CANONICAL_ISBN13, provider: "evil"
      }
    end

    assert_response :unprocessable_entity
    assert_match(/unsupported provider|failed/i, response.body)
  end

  test "accept creates product variant creators and enrichment event then redirects to show" do
    assert_difference [ "Product.count", "CatalogEnrichmentEvent.count" ], 1 do
      post accept_product_imports_path, params: accept_params
    end

    product = Product.find_by!(identifier: CANONICAL_ISBN13)
    assert_redirected_to product_path(product)
    assert_equal "Test Harbor", product.name
    assert_nil product.product_variants.first.regular_price_cents
    event = CatalogEnrichmentEvent.find_by!(product: product)
    assert_equal "isbndb", event.provider
    assert_equal CANONICAL_ISBN13, event.provider_record_id
    assert_equal @retrieved_at, event.retrieved_at
  end

  test "accept with return_to redirects to the product request form" do
    assert_difference "Product.count", 1 do
      post accept_product_imports_path, params: accept_params.merge(
        return_to: new_product_request_path
      )
    end

    product = Product.find_by!(identifier: CANONICAL_ISBN13)
    assert_redirected_to new_product_request_path(product_id: product.id)
  end

  test "accept validation failure with valid token rerenders preview and keeps submitted title" do
    assert_no_difference "Product.count" do
      post accept_product_imports_path, params: accept_params.merge(
        name: "Kept Title",
        product_format_id: ""
      )
    end

    assert_response :unprocessable_entity
    assert_match(/Kept Title/, response.body)
    assert_match(/Preview product import/i, response.body)
  end

  test "accept without preview token is rejected" do
    assert_no_difference "Product.count" do
      post accept_product_imports_path, params: accept_params.except(:preview_token).merge(
        provider: "google_books",
        provider_record_id: "forged",
        retrieved_at: Time.current.iso8601,
        list_price_cents: 1
      )
    end

    assert_response :unprocessable_entity
    assert_match(/preview session|invalid/i, response.body)
  end

  test "accept ignores forged provenance fields when token is valid" do
    assert_difference "CatalogEnrichmentEvent.count", 1 do
      post accept_product_imports_path, params: accept_params.merge(
        provider: "google_books",
        provider_record_id: "forged-record",
        retrieved_at: "1999-01-01T00:00:00Z",
        list_price_cents: 1,
        list_price_currency_code: "EUR",
        accepted_warnings: [ { code: "forged", message: "nope" } ]
      )
    end

    product = Product.find_by!(identifier: CANONICAL_ISBN13)
    event = CatalogEnrichmentEvent.find_by!(product: product)
    assert_equal "isbndb", event.provider
    assert_equal CANONICAL_ISBN13, event.provider_record_id
    assert_equal @retrieved_at, event.retrieved_at
    assert_equal 1699, product.list_price_cents
  end

  test "accept rejects expired preview token" do
    token = preview_token

    travel_to 31.minutes.from_now do
      assert_no_difference "Product.count" do
        post accept_product_imports_path, params: accept_params(token: token)
      end
    end

    assert_response :unprocessable_entity
    assert_match(/expired/i, response.body)
  end

  test "accept rejects preview token issued for another actor" do
    token = Catalog::ProductImportPreviewToken.issue(
      organization: @organization,
      actor: users(:clerk),
      normalized_result: normalized_result_for_token,
      warnings: []
    )

    assert_no_difference "Product.count" do
      post accept_product_imports_path, params: accept_params(token: token)
    end

    assert_response :unprocessable_entity
    assert_match(/does not belong|invalid/i, response.body)
  end

  private

  def normalized_result_for_token
    Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: CANONICAL_ISBN13,
      canonical_identifier: CANONICAL_ISBN13,
      provider: "isbndb",
      provider_record_id: CANONICAL_ISBN13,
      retrieved_at: @retrieved_at,
      title: "Test Harbor",
      list_price: { amount: "16.99", currency_code: "USD" }
    )
  end

  def preview_token
    Catalog::ProductImportPreviewToken.issue(
      organization: @organization,
      actor: @actor,
      normalized_result: normalized_result_for_token,
      warnings: []
    )
  end

  def accept_params(token: preview_token)
    {
      preview_token: token,
      name: "Test Harbor",
      product_type: "book",
      product_format_id: product_formats(:paperback).id,
      publisher_or_manufacturer_name: "Fixture House",
      language_code: "en",
      edition_statement: "1st",
      publication_date: "2014-02-11",
      publication_date_precision: "day",
      inventory_tracking_mode: "quantity",
      creators: {
        "0" => { action: "create", display_name: "Jordan Fixture", role: "author" },
        "1" => { action: "create", display_name: "Alex Sample", role: "author" }
      }
    }
  end
end
