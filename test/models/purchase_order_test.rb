# frozen_string_literal: true

require "test_helper"

class PurchaseOrderTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @vendor = vendors(:acme_distributor)
  end

  test "requires purchase_order_number unique within store" do
    po = PurchaseOrder.new(
      store: @store, vendor: @vendor, purchase_order_number: "001-PO-00001",
      status: "draft", currency_code: "USD"
    )
    assert_not po.valid?
    assert_includes po.errors[:purchase_order_number], "has already been taken"
  end

  test "vendor must belong to the same organization as the store" do
    # INV-ORG-001 forbids a second Organization row; stamp an unsaved Vendor
    # with a different organization_id instead.
    fake_org = Organization.new(
      id: organizations(:acme).id + 999_999, code: "other", name: "Other Org",
      default_currency_code: "USD", default_timezone: "America/New_York"
    )
    other_vendor = Vendor.new(organization: fake_org, code: "OTH", name: "Other Vendor", active: true)
    po = PurchaseOrder.new(
      store: @store, vendor: other_vendor, purchase_order_number: "001-PO-00099",
      status: "draft", currency_code: "USD"
    )
    assert_not po.valid?
    assert_includes po.errors[:vendor], "must belong to the same organization as the store"
  end

  test "vendor must be active while draft" do
    inactive = vendors(:inactive_vendor)
    po = PurchaseOrder.new(
      store: @store, vendor: inactive, purchase_order_number: "001-PO-00098",
      status: "draft", currency_code: "USD"
    )
    assert_not po.valid?
    assert_includes po.errors[:vendor], "must be active to create or edit a draft purchase order"
  end

  test "vendor, store, and currency are immutable after placement" do
    po = purchase_orders(:ordered_po)
    po.currency_code = "CAD"
    assert_not po.save
    assert_includes po.errors[:base], "vendor, store, and currency are immutable after placement"
  end

  test "draft header attributes remain editable" do
    po = purchase_orders(:draft_po)
    po.vendor_reference = "PO-REF-1"
    assert po.save
  end

  test "receiving_state is not_received with no lines received or cancelled" do
    po = purchase_orders(:ordered_po)
    assert_equal "not_received", po.receiving_state
  end

  test "receiving_state is fully_received when open quantity reaches zero" do
    po = purchase_orders(:ordered_po)
    line = purchase_order_lines(:ordered_po_line1)
    line.update!(cancelled_quantity: line.ordered_quantity)
    assert_equal "fully_received", po.reload.receiving_state
  end

  test "receiving_state is not_received for an empty draft" do
    po = PurchaseOrder.create!(
      store: @store, vendor: @vendor, purchase_order_number: "001-PO-00097",
      status: "draft", currency_code: "USD"
    )
    assert_equal "not_received", po.receiving_state
  end
end

class PurchaseOrderLineTest < ActiveSupport::TestCase
  setup do
    @draft_po = purchase_orders(:draft_po)
    @ordered_po = purchase_orders(:ordered_po)
    @variant = product_variants(:sample_book_standard)
  end

  test "open_quantity is max(ordered - received - cancelled, 0)" do
    line = purchase_order_lines(:draft_po_line1)
    line.update!(cancelled_quantity: 3)
    assert_equal 7, line.open_quantity

    line.update_column(:received_quantity, 20)
    assert_equal 0, line.reload.open_quantity
  end

  test "cancelled_quantity cannot exceed ordered_quantity" do
    line = purchase_order_lines(:draft_po_line1)
    line.cancelled_quantity = line.ordered_quantity + 1
    assert_not line.valid?
    assert_includes line.errors[:cancelled_quantity], "must not exceed ordered quantity"
  end

  test "discount_from_list derives expected_unit_cost_cents deterministically" do
    line = @draft_po.purchase_order_lines.build(
      product_variant: @variant, ordered_quantity: 4, position: 1,
      cost_entry_method: "discount_from_list", list_cost_cents: 1999, discount_bps: 2500
    )
    assert line.valid?, line.errors.full_messages.to_sentence
    assert_equal 1499, line.expected_unit_cost_cents
    assert_equal 5996, line.expected_extended_cost_cents
  end

  test "direct_net_cost requires manual expected_unit_cost_cents and is not overwritten" do
    line = @draft_po.purchase_order_lines.build(
      product_variant: @variant, ordered_quantity: 2, position: 1,
      cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 850
    )
    assert line.valid?, line.errors.full_messages.to_sentence
    assert_equal 850, line.expected_unit_cost_cents
    assert_equal 1700, line.expected_extended_cost_cents
  end

  test "discount_from_list requires a list cost" do
    line = @draft_po.purchase_order_lines.build(
      product_variant: @variant, ordered_quantity: 2, position: 1,
      cost_entry_method: "discount_from_list", expected_unit_cost_cents: 100
    )
    assert_not line.valid?
    assert_includes line.errors[:list_cost_cents], "is required when using discount-from-list pricing"
  end

  test "line identity is immutable after placement except cancelled_quantity" do
    line = purchase_order_lines(:ordered_po_line1)
    line.ordered_quantity = line.ordered_quantity + 1
    assert_not line.save
    assert_includes line.errors[:base],
      "line identity is immutable after placement; only cancelled_quantity may change"
  end

  test "cancelled_quantity may change once the purchase order is ordered" do
    line = purchase_order_lines(:ordered_po_line1)
    line.cancelled_quantity = 1
    assert line.save, line.errors.full_messages.to_sentence
  end

  test "lines cannot be destroyed once the purchase order is no longer draft" do
    line = purchase_order_lines(:ordered_po_line1)
    assert_not line.destroy
    assert_includes line.errors[:base], "lines can only be removed while the purchase order is draft"
  end

  test "variant must belong to the store's organization" do
    # INV-ORG-001 forbids a second Organization row; build an unsaved
    # Product/Variant graph stamped with a different organization instead.
    fake_org = Organization.new(
      id: organizations(:acme).id + 999_999, code: "other2", name: "Other Org 2",
      default_currency_code: "USD", default_timezone: "America/New_York"
    )
    fake_product = Product.new(organization: fake_org, name: "Other Product")
    fake_variant = ProductVariant.new(product: fake_product, sku: "9999999999999", name: "Standard")

    line = @draft_po.purchase_order_lines.build(
      product_variant: fake_variant, ordered_quantity: 1, position: 1,
      cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 100
    )
    assert_not line.valid?
    assert_includes line.errors[:product_variant], "must belong to the same organization as the purchase order's store"
  end
end
