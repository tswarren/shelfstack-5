# frozen_string_literal: true

module Pos
  # POS-specific product/variant lookup rows for Product lookup overlay and
  # Transaction scan-resolution. Reuses Catalog::SearchRecords / SaleEligibility.
  class ProductLookupResults < ApplicationService
    LIMIT = 25

    VariantRow = Data.define(
      :product_variant_id, :variant_label, :sku, :tracking_mode,
      :price_cents, :available_quantity, :addable?, :blockers, :warnings,
      :inactive?, :status_note, :inventory_unit_id, :inventory_unit_identifier
    )
    ProductGroup = Data.define(
      :product_id, :title, :identifier, :variants
    )
    Result = Data.define(:query, :groups, :inventory_unit)

    def initialize(organization:, store:, query:, limit: LIMIT)
      @organization = organization
      @store = store
      @query = query.to_s.strip
      @limit = limit
    end

    def call
      return Result.new(query: @query, groups: [], inventory_unit: nil) if @query.blank?

      unit = find_inventory_unit
      variants = if unit
        [ unit.product_variant ]
      else
        Catalog::SearchRecords.call(
          organization: @organization,
          record_type: "product_variant",
          query: @query,
          include_inactive: true
        ).first(@limit).filter_map { |row| ProductVariant.find_by(id: row.id) }
      end

      groups = variants.group_by(&:product).map do |product, product_variants|
        ProductGroup.new(
          product_id: product.id,
          title: product.name,
          identifier: product.identifier,
          variants: product_variants.map { |variant| build_variant_row(variant, unit) }
        )
      end

      Result.new(query: @query, groups: groups, inventory_unit: unit)
    end

    def self.as_scan_candidates(result)
      result.groups.map do |group|
        {
          "product_id" => group.product_id,
          "title" => group.title,
          "identifier" => group.identifier,
          "variants" => group.variants.map { |row| candidate_variant_hash(row) }
        }
      end
    end

    def self.candidate_variant_hash(row)
      {
        "id" => row.product_variant_id,
        "sku" => row.sku,
        "label" => row.variant_label,
        "tracking_mode" => row.tracking_mode,
        "price_cents" => row.price_cents,
        "available_quantity" => row.available_quantity,
        "addable" => row.addable?,
        "blockers" => row.blockers,
        "warnings" => row.warnings,
        "inactive" => row.inactive?,
        "status_note" => row.status_note,
        "inventory_unit_id" => row.inventory_unit_id,
        "inventory_unit_identifier" => row.inventory_unit_identifier
      }
    end

    private

    def find_inventory_unit
      normalized = Identifiers::Normalize.call(@query)
      candidate = normalized.canonical.presence || normalized.normalized.presence || @query
      return nil if candidate.blank?

      InventoryUnit.joins(product_variant: :product)
        .where(products: { organization_id: @organization.id })
        .find_by(unit_identifier: candidate)
    end

    def build_variant_row(variant, matched_unit)
      eligibility = Catalog::SaleEligibility.call(variant: variant, store: @store)
      balance = variant.inventory_tracking_mode == "quantity" ?
        StockBalance.find_by(store_id: @store.id, product_variant_id: variant.id) : nil
      available = balance&.available
      inactive = variant.status != "active" || variant.product.status != "active"
      unit = matched_unit if matched_unit&.product_variant_id == variant.id
      blockers = eligibility.blockers
      addable = blockers.empty?

      VariantRow.new(
        product_variant_id: variant.id,
        variant_label: "#{variant.name.presence || 'Standard'} · SKU #{variant.sku}",
        sku: variant.sku,
        tracking_mode: variant.inventory_tracking_mode,
        price_cents: variant.regular_price_cents,
        available_quantity: available,
        addable?: addable,
        blockers: blockers,
        warnings: eligibility.warnings,
        inactive?: inactive,
        status_note: status_note_for(variant, inactive, blockers),
        inventory_unit_id: unit&.id,
        inventory_unit_identifier: unit&.unit_identifier
      )
    end

    def status_note_for(variant, inactive, blockers)
      notes = []
      notes << "inactive" if inactive
      notes << "restricted" if blockers.any?
      notes << "tracking #{variant.inventory_tracking_mode}" if variant.inventory_tracking_mode.present?
      notes.join(" · ").presence
    end
  end
end
