# frozen_string_literal: true

module Catalog
  class Lookup < ApplicationService
    def initialize(organization:, query:)
      @organization = organization
      @query = query
    end

    def call
      normalized = Identifiers::Normalize.call(@query)
      return nil if normalized.canonical.blank? && normalized.normalized.blank?

      canonical = normalized.canonical.presence
      find_by_identifier(canonical) || find_by_sku(canonical) || find_by_alternate(normalized)
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
      return nil if normalized.normalized.blank?

      @organization.products.find_by(alternate_identifier: normalized.normalized)
    end
  end
end
