# frozen_string_literal: true

module Catalog
  # Org-scoped local Product find by canonical / equivalent identifier
  # (Gate 8c). Reuses Catalog::Lookup uniqueness rules. Never calls a
  # provider. Used before PreviewProductImport / CreateFromEnrichment so an
  # existing Product short-circuits external lookup.
  class FindExistingProduct < ApplicationService
    FindResult = Data.define(:product, :products, :match_kind, :canonical_identifier, :normalized) do
      def found?
        products.any?
      end

      def ambiguous?
        products.size > 1
      end

      def empty?
        products.empty?
      end
    end

    def initialize(organization:, identifier:)
      @organization = organization
      @identifier = identifier
    end

    def call
      normalized = Identifiers::Normalize.call(@identifier)
      lookup = Catalog::Lookup.call(organization: @organization, query: @identifier)
      # Catalog::Lookup reports :alternate even when the alternate list is empty;
      # normalize that to :none for callers that only care about a real hit.
      match_kind = lookup.products.empty? ? :none : lookup.match_kind

      FindResult.new(
        product: lookup.product,
        products: lookup.products,
        match_kind: match_kind,
        canonical_identifier: normalized.canonical.presence || normalized.normalized,
        normalized: normalized
      )
    end
  end
end
