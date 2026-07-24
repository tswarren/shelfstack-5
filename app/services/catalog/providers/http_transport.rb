# frozen_string_literal: true

module Catalog
  module Providers
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
