# frozen_string_literal: true

module Catalog
  module Providers
    # Envelope returned by every provider adapter's #lookup and by
    # Catalog::LookupExternalMetadata itself (OD-P8-04 failure codes):
    # `not_found`, `ambiguous_result`, `authentication_failed`, `rate_limited`,
    # `timeout`, `provider_unavailable`, `invalid_response`, `unsupported_identifier`.
    AdapterResult = Data.define(:success?, :normalized_result, :code, :message, :metadata) do
      def self.success(normalized_result)
        new(success?: true, normalized_result: normalized_result, code: nil, message: nil, metadata: {})
      end

      def self.failure(code, message, metadata: {})
        new(success?: false, normalized_result: nil, code: code, message: message, metadata: metadata)
      end
    end
  end
end
