# frozen_string_literal: true

require "test_helper"

class CatalogProvidersRetryPolicyTest < ActiveSupport::TestCase
  class Caller
    include Catalog::Providers::RetryPolicy
  end

  setup do
    @caller = Caller.new
  end

  test "retries exactly once on a 503 then returns the successful response" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {}),
      Catalog::Providers::HttpTransport::Response.new(status: 200, body: "ok", headers: {})
    ])

    response = @caller.get_with_retry(transport: transport, url: "https://example.test/resource")

    assert_equal 200, response.status
    assert_equal 2, transport.call_count
  end

  test "never retries a second time -- two consecutive 503s return the second failure" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {}),
      Catalog::Providers::HttpTransport::Response.new(status: 503, body: "", headers: {})
    ])

    response = @caller.get_with_retry(transport: transport, url: "https://example.test/resource")

    assert_equal 503, response.status
    assert_equal 2, transport.call_count
  end

  test "retries once on a connection error then succeeds" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::ConnectionError.new("boom"),
      Catalog::Providers::HttpTransport::Response.new(status: 200, body: "ok", headers: {})
    ])

    response = @caller.get_with_retry(transport: transport, url: "https://example.test/resource")

    assert_equal 200, response.status
    assert_equal 2, transport.call_count
  end

  test "raises after exhausting the single retry on repeated timeouts" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::TimeoutError.new("slow"),
      Catalog::Providers::HttpTransport::TimeoutError.new("slow again")
    ])

    assert_raises(Catalog::Providers::HttpTransport::TimeoutError) do
      @caller.get_with_retry(transport: transport, url: "https://example.test/resource")
    end
    assert_equal 2, transport.call_count
  end

  test "never retries a 429 -- returns it immediately for the caller to map to rate_limited" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 429, body: "", headers: { "retry-after" => "30" })
    ])

    response = @caller.get_with_retry(transport: transport, url: "https://example.test/resource")

    assert_equal 429, response.status
    assert_equal 1, transport.call_count
  end

  test "never retries a 401 authentication failure" do
    transport = FakeHttpTransport.new(responses: [
      Catalog::Providers::HttpTransport::Response.new(status: 401, body: "", headers: {})
    ])

    response = @caller.get_with_retry(transport: transport, url: "https://example.test/resource")

    assert_equal 401, response.status
    assert_equal 1, transport.call_count
  end
end
