# frozen_string_literal: true

module Catalog
  LookupResult = Data.define(:products, :match_kind) do
    def product
      products.first if products.size == 1
    end

    def ambiguous?
      products.size > 1
    end

    def empty?
      products.empty?
    end
  end

  class Lookup < ApplicationService
    def initialize(organization:, query:)
      @organization = organization
      @query = query
    end

    def call
      normalized = Identifiers::Normalize.call(@query)
      return LookupResult.new(products: [], match_kind: :none) if normalized.canonical.blank? && normalized.normalized.blank?

      canonical = normalized.canonical.presence
      by_identifier = find_by_identifier(canonical)
      return LookupResult.new(products: [ by_identifier ], match_kind: :identifier) if by_identifier

      by_sku = find_by_sku(canonical)
      return LookupResult.new(products: [ by_sku ], match_kind: :sku) if by_sku

      alternates = find_by_alternate(normalized)
      kind = alternates.size > 1 ? :alternate_ambiguous : :alternate
      LookupResult.new(products: alternates, match_kind: kind)
    end

    private

    def find_by_identifier(canonical)
      return nil if canonical.blank?

      @organization.products.find_by(identifier: canonical)
    end

    def find_by_sku(canonical)
      return nil if canonical.blank?

      ProductVariant.joins(:product)
                    .where(products: { organization_id: @organization.id })
                    .find_by(sku: canonical)
                    &.product
    end

    def find_by_alternate(normalized)
      value = normalized.normalized.presence || normalized.canonical.presence
      return [] if value.blank?

      @organization.products.where(alternate_identifier: value).order(:id).to_a
    end
  end
end
