# frozen_string_literal: true

module Purchasing
  # Shared snapshot defaults applied when building a Purchase-Order Line so
  # description/identifier/SKU/vendor-item and returnability survive later
  # catalog or vendor-source edits (vendors-and-purchasing.md#purchase-order-line).
  #
  # Cost fields blank on the line are filled from the resolved Product Variant
  # Vendor when present. Catalog selling price (`regular_price_cents`) is never
  # used as cost — expected cost comes from vendor-source list/discount/net
  # values or explicit manual entry only.
  module LineSnapshot
    module_function

    def apply!(line)
      variant = line.product_variant
      return if variant.blank?

      line.description_snapshot = line.description_snapshot.presence || variant.name
      line.sku_snapshot = line.sku_snapshot.presence || variant.sku
      line.identifier_snapshot = line.identifier_snapshot.presence || variant.product&.identifier

      resolve_vendor_source!(line)
      source = line.product_variant_vendor
      return if source.blank?

      line.vendor_item_code_snapshot = line.vendor_item_code_snapshot.presence || source.vendor_item_code
      line.returnable_snapshot = source.returnable if line.returnable_snapshot.nil?
      line.cost_provenance ||= "vendor_source"
      apply_cost_defaults!(line, source)
    end

    def resolve_vendor_source!(line)
      return if line.product_variant_vendor.present?

      vendor_id = line.purchase_order&.vendor_id
      return if vendor_id.blank? || line.product_variant_id.blank?

      source = ProductVariantVendor
        .where(product_variant_id: line.product_variant_id, vendor_id: vendor_id, active: true)
        .order(preferred: :desc, id: :asc)
        .first
      line.product_variant_vendor = source if source
    end
    module_function :resolve_vendor_source!

    def apply_cost_defaults!(line, source)
      line.list_cost_cents = source.list_cost_cents if line.list_cost_cents.nil?
      line.discount_bps = source.discount_bps if line.discount_bps.nil?
      line.expected_unit_cost_cents = source.expected_unit_cost_cents if line.expected_unit_cost_cents.nil?

      return if line.cost_entry_method.present?

      line.cost_entry_method = if line.list_cost_cents.present? || source.list_cost_cents.present?
        "discount_from_list"
      else
        "direct_net_cost"
      end
    end
    module_function :apply_cost_defaults!
  end
end
