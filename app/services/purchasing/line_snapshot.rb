# frozen_string_literal: true

module Purchasing
  # Shared snapshot defaults applied when building a Purchase-Order Line so
  # description/identifier/SKU/vendor-item and returnability survive later
  # catalog or vendor-source edits (vendors-and-purchasing.md#purchase-order-line).
  module LineSnapshot
    module_function

    def apply!(line)
      variant = line.product_variant
      return if variant.blank?

      line.description_snapshot = line.description_snapshot.presence || variant.name
      line.sku_snapshot = line.sku_snapshot.presence || variant.sku
      line.identifier_snapshot = line.identifier_snapshot.presence || variant.product&.identifier

      source = line.product_variant_vendor
      return if source.blank?

      line.vendor_item_code_snapshot = line.vendor_item_code_snapshot.presence || source.vendor_item_code
      line.returnable_snapshot = source.returnable if line.returnable_snapshot.nil?
      line.cost_provenance ||= "vendor_source"
    end
  end
end
