# frozen_string_literal: true

module Catalog
  module Providers
    # Shared bounded-retry contract (Gate 8b Slice 2), included by each
    # adapter and driven against whichever transport it was given:
    #
    # * at most one retry, ever;
    # * retry connection reset / temporary network failure / HTTP 502/503/504;
    # * never retry authentication failures or malformed responses (those
    #   never raise the errors below, and are never in RETRIABLE_STATUSES);
    # * HTTP 429 is never retried and never sleeps here -- adapters map it to
    #   `rate_limited` directly.
    module RetryPolicy
      MAX_RETRIES = 1
      RETRIABLE_STATUSES = [ 502, 503, 504 ].freeze

      def get_with_retry(transport:, url:, headers: {})
        attempts = 0

        loop do
          begin
            response = transport.get(url: url, headers: headers)
            return response unless RETRIABLE_STATUSES.include?(response.status) && attempts < MAX_RETRIES

            attempts += 1
          rescue Catalog::Providers::HttpTransport::ConnectionError, Catalog::Providers::HttpTransport::TimeoutError
            raise if attempts >= MAX_RETRIES

            attempts += 1
          end
        end
      end
    end
  end
end
