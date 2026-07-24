# frozen_string_literal: true

require "test_helper"

class ProductImportsControllerTest < ActionDispatch::IntegrationTest
  CANONICAL_ISBN13 = "9780316769488"

  setup do
    IdentifierSequence.ensure_defaults!
    post session_path, params: { username: "admin", password: "password123" }
  end

  teardown do
    Catalog::Providers.transport_override = nil
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
      }
    end

    assert_response :success
    assert_match(/Preview product import/i, response.body)
    assert_match(/Test Harbor/, response.body)
    assert_match(/external list price/i, response.body)
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

  test "accept creates product variant creators and enrichment event then redirects to show" do
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    assert_difference [ "Product.count", "CatalogEnrichmentEvent.count" ], 1 do
      post accept_product_imports_path, params: accept_params
    end

    product = Product.find_by!(identifier: CANONICAL_ISBN13)
    assert_redirected_to product_path(product)
    assert_equal "Test Harbor", product.name
    assert_nil product.product_variants.first.regular_price_cents
    assert_equal 1, CatalogEnrichmentEvent.where(product: product).count
  end

  test "accept validation failure rerenders preview and keeps submitted title" do
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

  private

  def accept_params
    {
      identifier: CANONICAL_ISBN13,
      provider: "isbndb",
      provider_record_id: CANONICAL_ISBN13,
      retrieved_at: Time.zone.parse("2026-07-24 12:00:00").iso8601,
      name: "Test Harbor",
      product_type: "book",
      product_format_id: product_formats(:paperback).id,
      publisher_or_manufacturer_name: "Fixture House",
      language_code: "en",
      edition_statement: "1st",
      publication_date: "2014-02-11",
      publication_date_precision: "day",
      list_price_cents: 1699,
      list_price_currency_code: "USD",
      inventory_tracking_mode: "quantity",
      creators: {
        "0" => { action: "create", display_name: "Jordan Fixture", role: "author" },
        "1" => { action: "create", display_name: "Alex Sample", role: "author" }
      }
    }
  end
end
