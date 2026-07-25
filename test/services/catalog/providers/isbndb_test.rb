# frozen_string_literal: true

require "test_helper"

class CatalogProvidersIsbndbTest < ActiveSupport::TestCase
  CANONICAL = "9780316769488"

  test "maps a successful response into a normalized result" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: "0316769487", canonical_identifier: CANONICAL)

    assert result.success?
    normalized = result.normalized_result
    assert_equal "Test Harbor", normalized.title
    assert_equal "isbndb", normalized.provider
    assert_equal CANONICAL, normalized.canonical_identifier
    assert_equal [ "Jordan Fixture", "Alex Sample" ], normalized.creators.map(&:display_name)
    assert_equal %w[author author], normalized.creators.map(&:role)
    assert_equal Date.new(2014, 2, 11), normalized.publication_date
    assert_equal 1699, normalized.list_price.amount_cents
    assert_equal "USD", normalized.list_price.currency_code
    assert_equal 1, transport.call_count
  end

  test "missing API key fails authentication with zero transport calls" do
    transport = FakeHttpTransport.new(responses: [])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: nil)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :authentication_failed, result.code
    assert_equal 0, transport.call_count
  end

  test "401 response maps to authentication_failed and is never retried" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 401, body: "", headers: {})
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "bad-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :authentication_failed, result.code
    assert_equal 1, transport.call_count
  end

  test "404 response maps to not_found" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 404, body: "", headers: {})
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :not_found, result.code
  end

  test "429 response maps to rate_limited with retry-after metadata and is never retried" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 429, body: "", headers: { "retry-after" => "12" })
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :rate_limited, result.code
    assert_equal "12", result.metadata[:retry_after]
    assert_equal 1, transport.call_count
  end

  test "retries once on a 503 then succeeds" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {}),
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert result.success?
    assert_equal 2, transport.call_count
  end

  test "never retries a second time -- two consecutive 503s surface provider_unavailable" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {}),
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {})
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :provider_unavailable, result.code
    assert_equal 2, transport.call_count
  end

  test "malformed JSON body maps to invalid_response" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/malformed.json")
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :invalid_response, result.code
  end

  test "response missing the book payload maps to invalid_response" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_missing_book.json")
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :invalid_response, result.code
  end

  test "root JSON array maps to invalid_response without raising" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, body: "[]")
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :invalid_response, result.code
  end

  test "book payload that is an array maps to invalid_response without raising" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, body: '{"book":[]}')
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :invalid_response, result.code
  end

  test "credential values never appear in a failure message" do
    secret = "super-secret-isbndb-key-should-not-leak"
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 401, body: "", headers: {})
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: secret)

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.message.include?(secret)
    # The transport call itself legitimately carries the credential in the Authorization
    # header (that is how the adapter authenticates) -- what must never leak is any
    # exception message or the AdapterResult surfaced back to callers/logs.
    assert_equal secret, transport.calls.first.headers["Authorization"]
  end

  test "a connection error after the single retry maps to provider_unavailable" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::ConnectionError.new("boom"),
      Catalog::Providers::HttpTransport::ConnectionError.new("boom again")
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :provider_unavailable, result.code
  end

  test "a timeout after the single retry maps to timeout" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::TimeoutError.new("slow"),
      Catalog::Providers::HttpTransport::TimeoutError.new("slow again")
    ])
    adapter = Catalog::Providers::Isbndb.new(transport: transport, api_key: "test-key")

    result = adapter.lookup(requested_identifier: CANONICAL, canonical_identifier: CANONICAL)

    assert_not result.success?
    assert_equal :timeout, result.code
  end
end
