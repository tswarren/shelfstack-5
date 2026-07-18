# frozen_string_literal: true

module Pos
  ResolveScanResult = Data.define(:variant, :product, :ambiguous, :blockers, :warnings, :match_kind, :error) do
    def resolved?
      variant.present?
    end
  end

  # Catalog scan resolution for the register scan/search field. ISBN-10/UPC-A/EAN-13
  # normalization and product lookup happen in Identifiers::Normalize / Catalog::Lookup;
  # this service adds exact-variant resolution and sale-eligibility surfacing for POS.
  class ResolveScan < ApplicationService
    def initialize(organization:, query:, store: nil)
      @organization = organization
      @query = query
      @store = store
    end

    def call
      lookup = Catalog::Lookup.call(organization: @organization, query: @query)

      if lookup.empty?
        return ResolveScanResult.new(
          variant: nil, product: nil, ambiguous: false, blockers: [], warnings: [],
          match_kind: lookup.match_kind, error: "not_found"
        )
      end

      if lookup.ambiguous?
        return ResolveScanResult.new(
          variant: nil, product: nil, ambiguous: true, blockers: [], warnings: [],
          match_kind: lookup.match_kind, error: "ambiguous_match"
        )
      end

      product = lookup.product
      variant = product.product_variants.first
      if variant.blank?
        return ResolveScanResult.new(
          variant: nil, product: product, ambiguous: false, blockers: [], warnings: [],
          match_kind: lookup.match_kind, error: "no_variant"
        )
      end

      eligibility = Catalog::SaleEligibility.call(variant: variant, store: @store)

      ResolveScanResult.new(
        variant: variant,
        product: product,
        ambiguous: false,
        blockers: eligibility.blockers,
        warnings: eligibility.warnings,
        match_kind: lookup.match_kind,
        error: nil
      )
    end
  end
end
