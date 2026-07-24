# frozen_string_literal: true

module Catalog
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

    # Injectable transport boundary (Gate 8b Slice 2). Adapters depend on
    # this interface, never on Net::HTTP directly, so tests can supply a
    # deterministic fake and make zero real network connections.
    #
    # A conforming transport performs exactly ONE attempt per #get call --
    # the bounded retry contract lives in Catalog::Providers::RetryPolicy,
    # which adapters mix in and drive against whatever transport they were
    # given (real or fake). This keeps the retry contract testable through
    # the fake transport instead of only through real sockets.
    class HttpTransport
      Response = Data.define(:status, :body, :headers)

      # Raised by a real transport after its single attempt fails for a
      # transient reason (DNS/connection reset, etc). Never includes request
      # headers/credentials in the message.
      ConnectionError = Class.new(StandardError)
      # Raised after the connect or read timeout elapses.
      TimeoutError = Class.new(StandardError)
      # Raised when a response body exceeds the transport's bounded size.
      ResponseTooLargeError = Class.new(StandardError)

      def get(url:, headers: {})
        raise NotImplementedError, "#{self.class} must implement #get"
      end
    end
  end
end
