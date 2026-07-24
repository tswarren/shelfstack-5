# frozen_string_literal: true

require "json"
require "uri"

module Catalog
  module Providers
    # Google Books adapter -- operator-selected optional secondary provider
    # (OD-P8-04). Keyless public lookup by default; an optional
    # SHELFSTACK_GOOGLE_BOOKS_API_KEY is appended only when present. Retains
    # only exact canonical-ISBN matches -- never accepts the first
    # relevance-ranked hit -- and distinguishes not_found from ambiguous_result
    # (including duplicate exact-ISBN hits).
    class GoogleBooks
      include Catalog::Providers::RetryPolicy

      BASE_URL = "https://www.googleapis.com/books/v1/volumes"

      def initialize(transport: Catalog::Providers::NetHttpTransport.new, api_key: ENV["SHELFSTACK_GOOGLE_BOOKS_API_KEY"])
        @transport = transport
        @api_key = api_key.presence
      end

      def lookup(requested_identifier:, canonical_identifier:)
        response = get_with_retry(transport: @transport, url: search_url(canonical_identifier), headers: {})
        interpret(response, requested_identifier, canonical_identifier)
      rescue Catalog::Providers::HttpTransport::TimeoutError
        Catalog::Providers::AdapterResult.failure(:timeout, "The request to Google Books timed out.")
      rescue Catalog::Providers::HttpTransport::ConnectionError, Catalog::Providers::HttpTransport::ResponseTooLargeError
        Catalog::Providers::AdapterResult.failure(:provider_unavailable, "Google Books is currently unavailable.")
      end

      private

      def search_url(canonical_identifier)
        query = { "q" => "isbn:#{canonical_identifier}" }
        query["key"] = @api_key if @api_key.present?
        "#{BASE_URL}?#{URI.encode_www_form(query)}"
      end

      def interpret(response, requested_identifier, canonical_identifier)
        case response.status
        when 200
          build_result(response, requested_identifier, canonical_identifier)
        when 401, 403
          Catalog::Providers::AdapterResult.failure(:authentication_failed, "Google Books rejected the configured credentials.")
        when 429
          Catalog::Providers::AdapterResult.failure(
            :rate_limited, "The Google Books rate limit was exceeded.", metadata: retry_after_metadata(response)
          )
        when 500..599
          Catalog::Providers::AdapterResult.failure(:provider_unavailable, "Google Books is currently unavailable.")
        else
          Catalog::Providers::AdapterResult.failure(:invalid_response, "Google Books returned an unexpected response.")
        end
      end

      def build_result(response, requested_identifier, canonical_identifier)
        payload = JSON.parse(response.body)
        unless payload.is_a?(Hash)
          return Catalog::Providers::AdapterResult.failure(:invalid_response, "Google Books returned a response that could not be parsed.")
        end

        raw_items = payload["items"]
        items = case raw_items
        when nil then []
        when Array then raw_items
        else
          return Catalog::Providers::AdapterResult.failure(:invalid_response, "Google Books returned a response that could not be parsed.")
        end
        unless items.all? { |item| item.is_a?(Hash) }
          return Catalog::Providers::AdapterResult.failure(:invalid_response, "Google Books returned a response that could not be parsed.")
        end

        exact_matches = items.select { |item| exact_isbn_match?(item, canonical_identifier) }

        case exact_matches.size
        when 0
          Catalog::Providers::AdapterResult.failure(:not_found, "No Google Books record with a matching ISBN was found.")
        when 1
          Catalog::Providers::AdapterResult.success(map(exact_matches.first, requested_identifier, canonical_identifier))
        else
          Catalog::Providers::AdapterResult.failure(
            :ambiguous_result,
            "Google Books returned more than one record with a matching ISBN.",
            metadata: { candidate_count: exact_matches.size }
          )
        end
      rescue JSON::ParserError, TypeError, NoMethodError
        Catalog::Providers::AdapterResult.failure(:invalid_response, "Google Books returned a response that could not be parsed.")
      end

      def exact_isbn_match?(item, canonical_identifier)
        return false unless item.is_a?(Hash)

        info = item["volumeInfo"]
        return false unless info.is_a?(Hash)

        identifiers = info["industryIdentifiers"]
        return false unless identifiers.nil? || identifiers.is_a?(Array)

        Array(identifiers).any? do |entry|
          next false unless entry.is_a?(Hash)

          Identifiers::Normalize.call(entry["identifier"]).canonical == canonical_identifier
        end
      end

      def map(item, requested_identifier, canonical_identifier)
        raise TypeError, "volume item must be a Hash" unless item.is_a?(Hash)

        info = item["volumeInfo"]
        raise TypeError, "volumeInfo must be a Hash" unless info.is_a?(Hash)

        date, precision = Catalog::Providers::ParseProviderDate.call(info["publishedDate"])

        Catalog::Enrichment::BuildNormalizedResult.call(
          requested_identifier: requested_identifier,
          canonical_identifier: canonical_identifier,
          provider: "google_books",
          provider_record_id: item["id"],
          retrieved_at: Time.current,
          title: info["title"],
          subtitle: info["subtitle"],
          description: info["description"],
          creators: Array(info["authors"]).map { |name| { display_name: name, role: "author" } },
          publisher: info["publisher"],
          publication_date: (date ? { date: date, precision: precision } : nil),
          language_code: info["language"],
          provider_format: info["printType"],
          external_subjects: info["categories"],
          list_price: money_input(item),
          images: image_input(info)
        )
      end

      def money_input(item)
        sale_info = item["saleInfo"]
        return nil unless sale_info.is_a?(Hash)

        list_price = sale_info["listPrice"]
        return nil unless list_price.is_a?(Hash)

        { amount: list_price["amount"], currency_code: list_price["currencyCode"] }
      end

      def image_input(info)
        links = info["imageLinks"]
        return [] unless links.is_a?(Hash)

        thumbnail = links["thumbnail"]
        thumbnail.present? ? [ { source_url: thumbnail } ] : []
      end

      def retry_after_metadata(response)
        value = response.headers["retry-after"]
        value.present? ? { retry_after: value } : {}
      end
    end
  end
end
