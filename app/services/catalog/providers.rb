# frozen_string_literal: true

module Catalog
  # Provider-adapter namespace (Gate 8b/8c). Module methods live here so
  # Zeitwerk loads them with Catalog::Providers itself — not only when
  # Catalog::Providers::HttpTransport happens to be autoloaded first.
  module Providers
    class << self
      # Optional process-wide transport for request/system tests (Gate 8c).
      # Production code never sets this; LookupExternalMetadata prefers an
      # explicit per-call `transport:` argument when present. Stored on
      # Rails.application.config.x so threaded Capybara servers see the same
      # object as the test thread.
      def transport_override
        Rails.application.config.x.catalog_provider_transport
      end

      def transport_override=(transport)
        Rails.application.config.x.catalog_provider_transport = transport
      end
    end
  end
end
