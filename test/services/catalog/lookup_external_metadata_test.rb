# frozen_string_literal: true

require "test_helper"

class CatalogLookupExternalMetadataTest < ActiveSupport::TestCase
  CANONICAL_ISBN13 = "9780316769488"

  setup do
    @admin = users(:admin)
    @clerk = users(:clerk)
    @store = stores(:main_street)
  end

  test "unknown provider symbol raises ArgumentError before any authorization or network work" do
    transport = FakeHttpTransport.new(responses: [])

    assert_raises(ArgumentError) do
      Catalog::LookupExternalMetadata.call(
        actor: @admin, store: @store, identifier: CANONICAL_ISBN13, provider: :not_a_real_provider, transport: transport
      )
    end
    assert_equal 0, transport.call_count
  end

  test "an actor without catalog.lookup_external is denied" do
    transport = FakeHttpTransport.new(responses: [])

    assert_raises(Catalog::LookupExternalMetadata::Error) do
      Catalog::LookupExternalMetadata.call(
        actor: @clerk, store: @store, identifier: CANONICAL_ISBN13, provider: :isbndb, transport: transport
      )
    end
    assert_equal 0, transport.call_count
  end

  test "a valid ISBN-13 proceeds to the provider adapter" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: CANONICAL_ISBN13, provider: :isbndb,
      transport: transport, api_key: "test-key"
    )

    assert result.success?
    assert_equal 1, transport.call_count
  end

  test "a valid ISBN-10 is canonicalized to ISBN-13 before the provider call" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: "0316769487", provider: :isbndb,
      transport: transport, api_key: "test-key"
    )

    assert result.success?
    assert_includes transport.calls.first.url, CANONICAL_ISBN13
  end

  test "a UPC-A identifier is unsupported with zero transport calls" do
    transport = FakeHttpTransport.new(responses: [])

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: "036000291452", provider: :isbndb, transport: transport
    )

    assert_not result.success?
    assert_equal :unsupported_identifier, result.code
    assert_equal 0, transport.call_count
  end

  test "a generated 28 product-variant identifier is unsupported with zero transport calls" do
    transport = FakeHttpTransport.new(responses: [])
    generated = Identifiers::Generate.call(namespace: "28")

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: generated, provider: :isbndb, transport: transport
    )

    assert_not result.success?
    assert_equal :unsupported_identifier, result.code
    assert_equal 0, transport.call_count
  end

  test "a malformed identifier is unsupported with zero transport calls" do
    transport = FakeHttpTransport.new(responses: [])

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: "not-an-isbn-at-all!!", provider: :isbndb, transport: transport
    )

    assert_not result.success?
    assert_equal :unsupported_identifier, result.code
    assert_equal 0, transport.call_count
  end

  test "an ISBN-13-shaped value with an invalid check digit is unsupported with zero transport calls" do
    transport = FakeHttpTransport.new(responses: [])
    invalid_checksum = "9780316769480"

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: invalid_checksum, provider: :isbndb, transport: transport
    )

    assert_not result.success?
    assert_equal :unsupported_identifier, result.code
    assert_equal 0, transport.call_count
  end

  test "an arbitrary non-Bookland EAN-13 is unsupported with zero transport calls" do
    transport = FakeHttpTransport.new(responses: [])
    non_bookland_ean13 = "4006381333931"

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: non_bookland_ean13, provider: :isbndb, transport: transport
    )

    assert_not result.success?
    assert_equal :unsupported_identifier, result.code
    assert_equal 0, transport.call_count
  end

  test "does not change any catalog or enrichment row counts on a successful lookup" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    assert_no_difference [
      -> { Product.count }, -> { ProductVariant.count }, -> { Creator.count },
      -> { ProductCreator.count }, -> { CatalogEnrichmentEvent.count }
    ] do
      Catalog::LookupExternalMetadata.call(
        actor: @admin, store: @store, identifier: CANONICAL_ISBN13, provider: :isbndb,
        transport: transport, api_key: "test-key"
      )
    end
  end

  test "does not change any catalog or enrichment row counts on a failed lookup" do
    transport = FakeHttpTransport.new(responses: [])

    assert_no_difference [
      -> { Product.count }, -> { ProductVariant.count }, -> { Creator.count },
      -> { ProductCreator.count }, -> { CatalogEnrichmentEvent.count }
    ] do
      Catalog::LookupExternalMetadata.call(
        actor: @admin, store: @store, identifier: "not-an-isbn", provider: :isbndb, transport: transport
      )
    end
  end

  test "routes to Google Books when provider: :google_books" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_success.json")
    ])

    result = Catalog::LookupExternalMetadata.call(
      actor: @admin, store: @store, identifier: CANONICAL_ISBN13, provider: :google_books, transport: transport
    )

    assert result.success?
    assert_equal "google_books", result.normalized_result.provider
  end
end
