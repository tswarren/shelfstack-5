# frozen_string_literal: true

require "test_helper"

class CatalogProvidersNetHttpTransportTest < ActiveSupport::TestCase
  test "rejects a non-HTTPS URL before attempting any connection" do
    transport = Catalog::Providers::NetHttpTransport.new

    assert_raises(ArgumentError) { transport.get(url: "http://example.test/insecure") }
  end
end
