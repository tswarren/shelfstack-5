# frozen_string_literal: true

module Purchasing
  # Pure helper returning soft warning strings for vendor minimum-order-quantity
  # and order-multiple thresholds. Never blocks placement — Phase 5 defers
  # universal hard enforcement and automatic tier qualification
  # (vendors-and-purchasing.md#vendor-source).
  module ThresholdWarnings
    module_function

    # lines: enumerable of objects responding to #ordered_quantity and
    # #product_variant_vendor (optional). Returns an array of warning strings.
    def call(lines)
      Array(lines).each_with_object([]) do |line, warnings|
        source = line.respond_to?(:product_variant_vendor) ? line.product_variant_vendor : nil
        next if source.blank?

        quantity = line.ordered_quantity.to_i
        label = line.respond_to?(:description_snapshot) ? line.description_snapshot.presence : nil
        label ||= line.respond_to?(:product_variant) ? line.product_variant&.name : nil
        label ||= "line"

        if source.minimum_order_quantity.present? && quantity < source.minimum_order_quantity
          warnings << "#{label}: quantity #{quantity} is below the vendor minimum order quantity (#{source.minimum_order_quantity})"
        end

        if source.order_multiple.present? && source.order_multiple.positive? && (quantity % source.order_multiple != 0)
          warnings << "#{label}: quantity #{quantity} is not a multiple of the vendor order multiple (#{source.order_multiple})"
        end
      end
    end
  end
end
