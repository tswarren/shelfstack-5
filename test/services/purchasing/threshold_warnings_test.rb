# frozen_string_literal: true

require "test_helper"

module Purchasing
  class ThresholdWarningsTest < ActiveSupport::TestCase
    test "warns below minimum order quantity and non-multiple quantity" do
      line = purchase_order_lines(:draft_po_line1)
      line.product_variant_vendor.update!(minimum_order_quantity: 20, order_multiple: 3)

      warnings = ThresholdWarnings.call([ line ])

      assert warnings.any? { |w| w.match?(/minimum order quantity/i) }
      assert warnings.any? { |w| w.match?(/order multiple/i) }
    end

    test "no warnings without a vendor source" do
      line = purchase_order_lines(:draft_po_line1)
      line.update_column(:product_variant_vendor_id, nil)

      assert_empty ThresholdWarnings.call([ line ])
    end
  end
end
