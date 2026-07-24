# frozen_string_literal: true

require "test_helper"

class CatalogProvidersTransportOverrideTest < ActiveSupport::TestCase
  teardown do
    Catalog::Providers.transport_override = nil
  end

  test "transport_override is nil by default and not a truthy OrderedOptions" do
    Catalog::Providers.transport_override = nil

    assert_nil Catalog::Providers.transport_override
  end

  test "LookupExternalMetadata ignores a non-transport override and uses the real adapter transport" do
    # Simulate the config.x autovivification footgun that previously broke
    # live ISBNdb lookups in development.
    Catalog::Providers.transport_override = ActiveSupport::OrderedOptions.new

    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    result = Catalog::LookupExternalMetadata.call(
      actor: users(:admin),
      store: stores(:main_street),
      identifier: "9780316769488",
      provider: :isbndb,
      transport: transport,
      api_key: "test-key"
    )

    assert result.success?
    assert_equal 1, transport.call_count
  end

  test "LookupExternalMetadata uses an HttpTransport override when no per-call transport is given" do
    Catalog::Providers.transport_override = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])

    result = Catalog::LookupExternalMetadata.call(
      actor: users(:admin),
      store: stores(:main_street),
      identifier: "9780316769488",
      provider: :isbndb,
      api_key: "test-key"
    )

    assert result.success?
    assert_equal 1, Catalog::Providers.transport_override.call_count
  end
end
