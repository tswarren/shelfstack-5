# frozen_string_literal: true

module Catalog
  # Authorized facade over the provider adapters (Gate 8b Slice 2). Service
  # only -- no HTTP endpoint or lookup cache ship in 8b (Gate 8c adds the
  # preview controller/endpoint). Adapters and transport stay
  # authorization-free; this is the only layer that checks
  # `catalog.lookup_external`.
  #
  # Returns a Catalog::Providers::AdapterResult: success(NormalizedResult) or
  # failure(code, message, metadata). Creates no Product/Variant/Creator/
  # ProductCreator/CatalogEnrichmentEvent rows.
  class LookupExternalMetadata < ApplicationService
    # Missing `catalog.lookup_external` is a hard authorization failure, not
    # a provider-neutral failure code -- mirrors the "not permitted to ..."
    # convention used by other services (e.g. Requests::CreateProductRequest).
    Error = Class.new(StandardError)

    SUPPORTED_PROVIDERS = %i[isbndb google_books].freeze

    def initialize(actor:, store:, identifier:, provider:, transport: nil, api_key: nil)
      @actor = actor
      @store = store
      @identifier = identifier
      @provider = provider.respond_to?(:to_sym) ? provider.to_sym : provider
      @transport = transport
      @api_key = api_key
    end

    def call
      raise ArgumentError, "unsupported provider: #{@provider.inspect}" unless SUPPORTED_PROVIDERS.include?(@provider)
      raise Error, "not permitted to look up external metadata" unless authorized?

      normalized = Identifiers::Normalize.call(@identifier)
      return unsupported_identifier_result unless supported_identifier?(normalized)

      adapter.lookup(requested_identifier: @identifier, canonical_identifier: normalized.canonical)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: "catalog.lookup_external"
      ) == :allow
    end

    # Only a valid ISBN-13 / Bookland EAN-13 (978/979) proceeds -- ISBN-10 is
    # already canonicalized to ISBN-13 by Identifiers::Normalize. UPC,
    # generated 21/27/28/29 identifiers, other EAN-13 ranges, and malformed
    # input are unsupported (zero transport calls).
    def supported_identifier?(normalized)
      normalized.type == :isbn13 && normalized.validation_status == :valid
    end

    def unsupported_identifier_result
      Catalog::Providers::AdapterResult.failure(
        :unsupported_identifier, "This identifier is not a supported ISBN for external lookup."
      )
    end

    def adapter
      case @provider
      when :isbndb
        Catalog::Providers::Isbndb.new(**adapter_args)
      when :google_books
        Catalog::Providers::GoogleBooks.new(**adapter_args)
      end
    end

    def adapter_args
      args = {}
      transport = @transport || Catalog::Providers.transport_override
      # Only inject a real transport. config.x leftovers / OrderedOptions must
      # never win over the adapter's NetHttpTransport default.
      args[:transport] = transport if transport.is_a?(Catalog::Providers::HttpTransport)
      args[:api_key] = @api_key if @api_key
      args
    end
  end
end
