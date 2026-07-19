# frozen_string_literal: true

module Pos
  ResolveScanResult = Data.define(:variant, :product, :inventory_unit, :ambiguous, :blockers, :warnings, :match_kind, :error) do
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
      unit_result = resolve_inventory_unit
      return unit_result if unit_result

      lookup = Catalog::Lookup.call(organization: @organization, query: @query)

      if lookup.empty?
        return ResolveScanResult.new(
          variant: nil, product: nil, inventory_unit: nil, ambiguous: false, blockers: [], warnings: [],
          match_kind: lookup.match_kind, error: "not_found"
        )
      end

      if lookup.ambiguous?
        return ResolveScanResult.new(
          variant: nil, product: nil, inventory_unit: nil, ambiguous: true, blockers: [], warnings: [],
          match_kind: lookup.match_kind, error: "ambiguous_match"
        )
      end

      product = lookup.product
      variant = product.product_variants.first
      if variant.blank?
        return ResolveScanResult.new(
          variant: nil, product: product, inventory_unit: nil, ambiguous: false, blockers: [], warnings: [],
          match_kind: lookup.match_kind, error: "no_variant"
        )
      end

      eligibility = Catalog::SaleEligibility.call(variant: variant, store: @store)

      ResolveScanResult.new(
        variant: variant,
        product: product,
        inventory_unit: nil,
        ambiguous: false,
        blockers: eligibility.blockers,
        warnings: eligibility.warnings,
        match_kind: lookup.match_kind,
        error: nil
      )
    end

    private

    # Identifier namespace `27` is exclusive to Inventory Units (never a
    # product identifier, variant SKU, or alternate identifier — see
    # docs/reference/identifiers.md), so an exact match here is checked first
    # and cannot shadow the ordinary product/variant/alternate precedence.
    def resolve_inventory_unit
      normalized = Identifiers::Normalize.call(@query)
      return nil unless normalized.type == :generated_27 && normalized.validation_status == :valid
      return nil if @store.blank?

      unit = InventoryUnit.find_by(store_id: @store.id, unit_identifier: normalized.canonical)
      return nil if unit.blank?

      variant = unit.product_variant
      eligibility = Catalog::SaleEligibility.call(variant: variant, store: @store)
      blockers = eligibility.blockers.dup
      blockers << "unit_not_available" unless unit.available?

      ResolveScanResult.new(
        variant: variant,
        product: variant.product,
        inventory_unit: unit,
        ambiguous: false,
        blockers: blockers,
        warnings: eligibility.warnings,
        match_kind: :unit_identifier,
        error: nil
      )
    end
  end
end
