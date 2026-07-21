# frozen_string_literal: true

require "test_helper"

module Inventory
  class PostReceiptTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @quantity_variant = product_variants(:sample_book_standard)
      @other_quantity_variant = product_variants(:upc_product_standard)
      @individual_variant = product_variants(:signed_book_standard)
    end

    test "quantity receipt posts on_hand and updates PO received_quantity and on_order" do
      po_line = build_ordered_po_line(variant: @quantity_variant, ordered_quantity: 10, expected_unit_cost_cents: 700)
      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, purchase_order_line_id: po_line.id,
          delivered_quantity: 4, accepted_quantity: 4, actual_unit_cost_cents: 700,
          cost_quality: "actual", cost_provenance: "vendor_source" }
      ])

      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)

      assert result.success?, result.error
      assert result.receipt.posted?

      balance = StockBalance.find_by!(store: @store, product_variant: @quantity_variant)
      assert_equal 4, balance.on_hand
      assert_equal 2800, balance.inventory_value_cents
      assert_equal 700, balance.moving_average_cost_cents

      po_line.reload
      assert_equal 4, po_line.received_quantity
      assert_equal 6, po_line.open_quantity
    end

    test "multi-PO receipt updates each linked purchase order line" do
      po_line1 = build_ordered_po_line(variant: @quantity_variant, ordered_quantity: 5, expected_unit_cost_cents: 700)
      po_line2 = build_ordered_po_line(variant: @other_quantity_variant, ordered_quantity: 3, expected_unit_cost_cents: 900)

      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, purchase_order_line_id: po_line1.id,
          delivered_quantity: 5, accepted_quantity: 5, actual_unit_cost_cents: 700, cost_quality: "actual" },
        { product_variant_id: @other_quantity_variant.id, purchase_order_line_id: po_line2.id,
          delivered_quantity: 3, accepted_quantity: 3, actual_unit_cost_cents: 900, cost_quality: "actual" }
      ])

      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)

      assert result.success?, result.error
      assert_equal 5, po_line1.reload.received_quantity
      assert_equal 3, po_line2.reload.received_quantity
      assert_equal 3500, StockBalance.find_by!(store: @store, product_variant: @quantity_variant).inventory_value_cents
      assert_equal 2700, StockBalance.find_by!(store: @store, product_variant: @other_quantity_variant).inventory_value_cents
    end

    test "OD-014: receipt into negative on_hand splits settlement and positive entries" do
      StockBalance.create!(
        store: @store, product_variant: @quantity_variant,
        on_hand: -3, reserved: 0, unavailable: 0,
        inventory_value_cents: 0, moving_average_cost_cents: nil, cost_quality: "unknown",
        open_provisional_deficit_cost_cents: 1800, deficit_cost_quality: "actual"
      )

      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, delivered_quantity: 5, accepted_quantity: 5,
          actual_unit_cost_cents: 700, cost_quality: "actual", cost_provenance: "vendor_source" }
      ])

      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert result.success?, result.error

      balance = StockBalance.find_by!(store: @store, product_variant: @quantity_variant)
      assert_equal 2, balance.on_hand
      assert_equal 1400, balance.inventory_value_cents
      assert_equal 700, balance.moving_average_cost_cents
      assert_equal 0, balance.open_provisional_deficit_cost_cents
      assert_equal "unknown", balance.deficit_cost_quality

      settlement = InventoryLedgerEntry.find_by!(movement_type: "receipt_deficit_settlement", product_variant: @quantity_variant)
      assert_equal 3, settlement.quantity_delta
      assert_equal 0, settlement.inventory_value_delta_cents
      assert_equal 1800, settlement.provisional_cost_released_cents
      assert_equal "actual", settlement.provisional_deficit_cost_quality_snapshot
      assert_equal 300, settlement.settlement_variance_cents
      assert_equal "ordinary", settlement.settlement_variance_kind

      positive = InventoryLedgerEntry.find_by!(movement_type: "receipt", product_variant: @quantity_variant)
      assert_equal 2, positive.quantity_delta
      assert_equal 1400, positive.inventory_value_delta_cents
    end

    test "OD-014: receipt smaller than the deficit creates only a settlement entry" do
      StockBalance.create!(
        store: @store, product_variant: @quantity_variant,
        on_hand: -5, reserved: 0, unavailable: 0,
        inventory_value_cents: 0, moving_average_cost_cents: nil, cost_quality: "unknown",
        open_provisional_deficit_cost_cents: 3000, deficit_cost_quality: "actual"
      )

      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, delivered_quantity: 2, accepted_quantity: 2,
          actual_unit_cost_cents: 700, cost_quality: "actual" }
      ])

      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert result.success?, result.error

      balance = StockBalance.find_by!(store: @store, product_variant: @quantity_variant)
      assert_equal(-3, balance.on_hand)
      assert_equal 0, balance.inventory_value_cents
      assert_equal 1800, balance.open_provisional_deficit_cost_cents

      refute InventoryLedgerEntry.exists?(movement_type: "receipt", product_variant: @quantity_variant)
      settlement = InventoryLedgerEntry.find_by!(movement_type: "receipt_deficit_settlement", product_variant: @quantity_variant)
      assert_equal 2, settlement.quantity_delta
      assert_equal 1200, settlement.provisional_cost_released_cents
    end

    test "individual tracking creates one inventory unit per accepted unit" do
      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @individual_variant.id, delivered_quantity: 2, accepted_quantity: 2,
          actual_unit_cost_cents: 1200, cost_quality: "actual" }
      ])

      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)

      assert result.success?, result.error
      units = InventoryUnit.where(product_variant: @individual_variant, acquisition_source_type: "receipt_line")
      assert_equal 2, units.count
      assert units.all? { |u| u.status == "available" && u.acquisition_cost_cents == 1200 }
    end

    test "unknown receipt cost stays null, not zero" do
      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, delivered_quantity: 2, accepted_quantity: 2, cost_quality: "unknown" }
      ])

      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)

      assert result.success?, result.error
      balance = StockBalance.find_by!(store: @store, product_variant: @quantity_variant)
      assert_equal 2, balance.on_hand
      assert_nil balance.inventory_value_cents
      assert_nil balance.moving_average_cost_cents
      assert_equal "unknown", balance.cost_quality

      entry = InventoryLedgerEntry.find_by!(movement_type: "receipt", product_variant: @quantity_variant)
      assert_nil entry.unit_cost_cents
      assert_equal "unknown", entry.cost_quality
    end

    test "unlinked receipt line requires inventory.receipt.receive_unlinked" do
      grant(@clerk, "inventory.receipt.post")
      receipt = @store.receipts.create!(vendor: @vendor, receipt_number: "UNLINKED-1", status: "draft")
      receipt.receipt_lines.create!(
        product_variant: @quantity_variant, position: 0, delivered_quantity: 2, accepted_quantity: 2,
        actual_unit_cost_cents: 700, cost_quality: "actual"
      )

      result = PostReceipt.call(receipt: receipt, actor: @clerk, store: @store)

      assert_not result.success?
      assert_match(/receive_unlinked|without a purchase order line/i, result.error)
      assert receipt.reload.draft?
    end

    test "accepting more than PO open quantity requires inventory.receipt.over_receive" do
      po_line = build_ordered_po_line(variant: @quantity_variant, ordered_quantity: 2, expected_unit_cost_cents: 700)
      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, purchase_order_line_id: po_line.id,
          delivered_quantity: 5, accepted_quantity: 5, actual_unit_cost_cents: 700, cost_quality: "actual" }
      ])

      grant(@clerk, "inventory.receipt.post")
      denied = PostReceipt.call(receipt: receipt, actor: @clerk, store: @store)
      assert_not denied.success?
      assert_match(/over-receive/i, denied.error)
      assert receipt.reload.draft?

      grant(@clerk, "inventory.receipt.over_receive")
      allowed = PostReceipt.call(receipt: receipt, actor: @clerk, store: @store)
      assert allowed.success?, allowed.error
      assert_equal 5, po_line.reload.received_quantity
    end

    test "denies an actor without inventory.receipt.post" do
      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, delivered_quantity: 1, accepted_quantity: 1, cost_quality: "unknown" }
      ])

      result = PostReceipt.call(receipt: receipt, actor: @clerk, store: @store)

      assert_not result.success?
      assert_match(/not permitted to post receipts/i, result.error)
    end

    test "replaying an already-posted receipt is a no-op success" do
      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, delivered_quantity: 3, accepted_quantity: 3,
          actual_unit_cost_cents: 700, cost_quality: "actual" }
      ])

      first = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert first.success?, first.error
      assert_not first.replayed

      ledger_count = InventoryLedgerEntry.count
      unit_count = InventoryUnit.count

      second = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)

      assert second.success?
      assert second.replayed
      assert_equal ledger_count, InventoryLedgerEntry.count
      assert_equal unit_count, InventoryUnit.count
      assert_equal 3, StockBalance.find_by!(store: @store, product_variant: @quantity_variant).on_hand
    end

    test "a sale still posts correctly against stock received via a receipt" do
      receipt = build_receipt(lines_attributes: [
        { product_variant_id: @quantity_variant.id, delivered_quantity: 5, accepted_quantity: 5,
          actual_unit_cost_cents: 700, cost_quality: "actual" }
      ])
      PostReceipt.call(receipt: receipt, actor: @admin, store: @store)

      sale = PostLedgerEntry.call(
        store: @store, product_variant: @quantity_variant, movement_type: "sale", movement_kind: :sale,
        quantity_delta: -2, source: receipt.receipt_lines.first, posting_key: "test-sale-after-receipt",
        posted_by_user: @admin
      )

      assert_equal 3, sale.stock_balance.on_hand
      assert_equal 2100, sale.stock_balance.inventory_value_cents
      assert_equal 700, sale.ledger_entry.unit_cost_cents
    end

    private

    def build_ordered_po_line(variant:, ordered_quantity:, expected_unit_cost_cents:)
      po = PurchaseOrder.new(vendor: @vendor)
      created = Purchasing::CreatePurchaseOrder.call(
        purchase_order: po,
        lines_attributes: [ { product_variant_id: variant.id, ordered_quantity: ordered_quantity,
                               cost_entry_method: "direct_net_cost", expected_unit_cost_cents: expected_unit_cost_cents } ],
        actor: @admin, store: @store
      )
      raise created.error unless created.success?

      placed = Purchasing::PlacePurchaseOrder.call(purchase_order: created.purchase_order, actor: @admin, store: @store)
      raise placed.error unless placed.success?

      placed.purchase_order.purchase_order_lines.first
    end

    def build_receipt(lines_attributes:)
      created = CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: lines_attributes,
        actor: @admin, store: @store
      )
      raise created.error unless created.success?

      created.receipt
    end

    def grant(user, permission_code)
      membership = StoreMembership.find_by!(user: user, store: @store)
      RolePermission.find_or_create_by!(role: membership.role, permission: Permission.find_by!(code: permission_code))
    end
  end
end
