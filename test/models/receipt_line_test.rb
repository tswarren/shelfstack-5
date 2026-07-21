# frozen_string_literal: true

require "test_helper"

class ReceiptLineTest < ActiveSupport::TestCase
  setup do
    @receipt = receipts(:draft_receipt)
    @variant = product_variants(:sample_book_standard)
  end

  test "accepted plus rejected quantity must not exceed delivered quantity" do
    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, delivered_quantity: 2, accepted_quantity: 2, rejected_quantity: 1
    )

    assert_not line.valid?
    assert_includes line.errors[:base], "accepted plus rejected quantity must not exceed delivered quantity"
  end

  test "accepted_unavailable_quantity must not exceed accepted_quantity" do
    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, delivered_quantity: 3, accepted_quantity: 2,
      accepted_unavailable_quantity: 3
    )

    assert_not line.valid?
    assert_includes line.errors[:accepted_unavailable_quantity], "must not exceed accepted quantity"
  end

  test "purchase_order_line must belong to the receipt's vendor" do
    other_po_line = purchase_order_lines(:ordered_po_line1)
    other_po_line.purchase_order.update_column(:vendor_id, vendors(:inactive_vendor).id)

    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, purchase_order_line: other_po_line,
      delivered_quantity: 1, accepted_quantity: 1
    )

    assert_not line.valid?
    assert_includes line.errors[:purchase_order_line], "must belong to the receipt's vendor"
  end

  test "purchase_order_line must match the receipt line product variant" do
    po_line = purchase_order_lines(:ordered_po_line1)
    other_variant = product_variants(:upc_product_standard)

    line = @receipt.receipt_lines.build(
      position: 1, product_variant: other_variant, purchase_order_line: po_line,
      delivered_quantity: 1, accepted_quantity: 1
    )

    assert_not line.valid?
    assert_includes line.errors[:purchase_order_line], "must match the line's product variant"
  end

  test "blank product variant is derived from the linked purchase order line" do
    po_line = purchase_order_lines(:ordered_po_line1)

    line = @receipt.receipt_lines.build(
      position: 1, purchase_order_line: po_line,
      delivered_quantity: 1, accepted_quantity: 1
    )

    assert line.valid?, line.errors.full_messages.to_sentence
    assert_equal po_line.product_variant_id, line.product_variant_id
  end

  test "sellable_accepted_quantity subtracts accepted_unavailable_quantity" do
    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, delivered_quantity: 5, accepted_quantity: 5,
      accepted_unavailable_quantity: 2
    )

    assert_equal 3, line.sellable_accepted_quantity
  end

  test "rejects actual cost with confirmed_zero provenance" do
    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, delivered_quantity: 1, accepted_quantity: 1,
      actual_unit_cost_cents: 500, cost_quality: "actual", cost_provenance: "confirmed_zero"
    )

    assert_not line.valid?
    assert_includes line.errors[:cost_provenance], "must be manual_receipt for actual cost"
  end

  test "unknown cost requires nil amount and unknown provenance" do
    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, delivered_quantity: 1, accepted_quantity: 1,
      actual_unit_cost_cents: 100, cost_quality: "unknown", cost_provenance: "unknown"
    )

    assert_not line.valid?
    assert_includes line.errors[:actual_unit_cost_cents], "must be blank for unknown cost"
  end

  test "confirmed_zero requires zero amount" do
    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, delivered_quantity: 1, accepted_quantity: 1,
      actual_unit_cost_cents: 5, cost_quality: "confirmed_zero", cost_provenance: "confirmed_zero"
    )

    assert_not line.valid?
    assert_includes line.errors[:actual_unit_cost_cents], "must be zero for confirmed zero cost"
  end

  test "auto provenance requires estimated quality" do
    line = @receipt.receipt_lines.build(
      position: 1, product_variant: @variant, delivered_quantity: 1, accepted_quantity: 1,
      actual_unit_cost_cents: 700, cost_quality: "actual", cost_provenance: "purchase_order_expected"
    )

    assert_not line.valid?
    assert_includes line.errors[:cost_quality], "must be estimated for suggested provenance"
  end

  test "lines can only be changed while the receipt is draft" do
    line = receipt_lines(:draft_receipt_line1)
    @receipt.update_column(:status, "posted")

    line.notes = "late edit"
    assert_not line.save
    assert_includes line.errors[:base], "lines can only be changed while the receipt is draft"
  end
end
