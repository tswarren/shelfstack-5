# frozen_string_literal: true

require "json"

module Catalog
  module Providers
    # ISBNdb v2 adapter -- primary production provider (OD-P8-04). Adapters
    # are deliberately authorization-free and independently testable;
    # Catalog::LookupExternalMetadata owns the `catalog.lookup_external`
    # permission check.
    class Isbndb
      include Catalog::Providers::RetryPolicy

      BASE_URL = "https://api2.isbndb.com"

      def initialize(transport: Catalog::Providers::NetHttpTransport.new, api_key: ENV["SHELFSTACK_ISBNDB_API_KEY"])
        @transport = transport
        @api_key = api_key
      end

      def lookup(requested_identifier:, canonical_identifier:)
        return missing_credentials_result if @api_key.blank?

        response = get_with_retry(
          transport: @transport,
          url: "#{BASE_URL}/book/#{canonical_identifier}",
          headers: { "Authorization" => @api_key, "Accept" => "application/json" }
        )
        interpret(response, requested_identifier, canonical_identifier)
      rescue Catalog::Providers::HttpTransport::TimeoutError
        Catalog::Providers::AdapterResult.failure(:timeout, "The request to ISBNdb timed out.")
      rescue Catalog::Providers::HttpTransport::ConnectionError, Catalog::Providers::HttpTransport::ResponseTooLargeError
        Catalog::Providers::AdapterResult.failure(:provider_unavailable, "ISBNdb is currently unavailable.")
      end

      private

      def missing_credentials_result
        Catalog::Providers::AdapterResult.failure(:authentication_failed, "ISBNdb API credentials are not configured.")
      end

      def interpret(response, requested_identifier, canonical_identifier)
        case response.status
        when 200
          build_success(response, requested_identifier, canonical_identifier)
        when 401, 403
          Catalog::Providers::AdapterResult.failure(:authentication_failed, "ISBNdb rejected the configured credentials.")
        when 404
          Catalog::Providers::AdapterResult.failure(:not_found, "No ISBNdb record was found for this identifier.")
        when 429
          Catalog::Providers::AdapterResult.failure(
            :rate_limited, "The ISBNdb rate limit was exceeded.", metadata: retry_after_metadata(response)
          )
        when 500..599
          Catalog::Providers::AdapterResult.failure(:provider_unavailable, "ISBNdb is currently unavailable.")
        else
          Catalog::Providers::AdapterResult.failure(:invalid_response, "ISBNdb returned an unexpected response.")
        end
      end

      def build_success(response, requested_identifier, canonical_identifier)
        payload = JSON.parse(response.body)
        book = payload["book"]
        return Catalog::Providers::AdapterResult.failure(:invalid_response, "ISBNdb response was missing book data.") if book.blank?

        Catalog::Providers::AdapterResult.success(map(book, requested_identifier, canonical_identifier))
      rescue JSON::ParserError
        Catalog::Providers::AdapterResult.failure(:invalid_response, "ISBNdb returned a response that could not be parsed.")
      end

      def map(book, requested_identifier, canonical_identifier)
        date, precision = Catalog::Providers::ParseProviderDate.call(book["date_published"])

        Catalog::Enrichment::BuildNormalizedResult.call(
          requested_identifier: requested_identifier,
          canonical_identifier: canonical_identifier,
          provider: "isbndb",
          provider_record_id: (book["isbn13"] || book["isbn"]),
          retrieved_at: Time.current,
          title: book["title"],
          description: (book["synopsis"] || book["overview"]),
          creators: Array(book["authors"]).map { |name| { display_name: name, role: "author" } },
          publisher: book["publisher"],
          publication_date: (date ? { date: date, precision: precision } : nil),
          language_code: book["language"],
          edition_statement: book["edition"],
          provider_format: book["binding"],
          external_subjects: book["subjects"],
          list_price: money_input(book),
          images: (book["image"].present? ? [ { source_url: book["image"] } ] : [])
        )
      end

      def money_input(book)
        return nil if book["msrp"].blank?

        { amount: book["msrp"], currency_code: book["msrp_currency"] }
      end

      def retry_after_metadata(response)
        value = response.headers["retry-after"]
        value.present? ? { retry_after: value } : {}
      end
    end
  end
end
