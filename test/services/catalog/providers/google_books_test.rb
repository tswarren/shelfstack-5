# frozen_string_literal: true

require "test_helper"

class CatalogProvidersGoogleBooksTest < ActiveSupport::TestCase
  CANONICAL = "9780316769488"

  test "keyless lookup by default omits the key query parameter" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_success.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not_includes transport.calls.first.url, "key="
    assert_includes transport.calls.first.url, "isbn%3A#{CANONICAL}"
  end

  test "an optional API key is appended to the query" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_success.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: "optional-key")

    adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_includes transport.calls.first.url, "key=optional-key"
  end

  test "maps a single exact match into a normalized result" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_success.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert result.success?
    normalized = result.normalized_result
    assert_equal "Test Harbor", normalized.title
    assert_equal "A Fixture Novel", normalized.subtitle
    assert_equal "google_books", normalized.provider
    assert_equal [ "Jordan Fixture" ], normalized.creators.map(&:display_name)
    assert_equal 1699, normalized.list_price.amount_cents
    assert_equal "day", normalized.publication_date.precision
  end

  test "no exact ISBN match returns not_found even when other items exist" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_no_exact_match.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :not_found, result.code
  end

  test "zero items returns not_found" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_not_found.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :not_found, result.code
  end

  test "duplicate exact ISBN hits return ambiguous_result and never pick the first hit" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_ambiguous.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :ambiguous_result, result.code
    assert_equal 2, result.metadata[:candidate_count]
  end

  test "401 response maps to authentication_failed" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 401, body: "", headers: {})
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: "bad-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :authentication_failed, result.code
  end

  test "429 response maps to rate_limited with retry-after metadata and is never retried" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 429, body: "", headers: { "retry-after" => "5" })
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :rate_limited, result.code
    assert_equal "5", result.metadata[:retry_after]
    assert_equal 1, transport.call_count
  end

  test "retries once on a 503 then succeeds" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {}),
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/google_books_success.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert result.success?
    assert_equal 2, transport.call_count
  end

  test "never retries a second time -- two consecutive 503s surface provider_unavailable" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {}),
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {})
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :provider_unavailable, result.code
    assert_equal 2, transport.call_count
  end

  test "malformed JSON body maps to invalid_response" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/malformed.json")
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :invalid_response, result.code
  end

  test "items array containing null maps to invalid_response without raising" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, body: '{"items":[null]}')
    ])
    adapter = Catalog::Providers::GoogleBooks.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :invalid_response, result.code
  end
end
