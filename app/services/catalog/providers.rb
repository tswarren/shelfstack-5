# frozen_string_literal: true

module Catalog
  # Provider-adapter namespace (Gate 8b/8c). Module methods live here so
  # Zeitwerk loads them with Catalog::Providers itself — not only when
  # Catalog::Providers::HttpTransport happens to be autoloaded first.
  module Providers
    class << self
      # Optional process-wide transport for request/system tests (Gate 8c).
      # Production code never sets this; LookupExternalMetadata prefers an
      # explicit per-call `transport:` argument when present.
      #
      # Intentionally a module ivar — do NOT store this on
      # Rails.application.config.x. Unset `config.x.some_key` returns a
      # truthy empty ActiveSupport::OrderedOptions (for nested assignment),
      # which would be mistaken for a transport and break live lookups.
      attr_accessor :transport_override
    end
  end
end
