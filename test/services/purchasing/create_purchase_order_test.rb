# frozen_string_literal: true

require "test_helper"

module Purchasing
  class CreatePurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @user = users(:admin)
      @variant = product_variants(:sample_book_standard)
    end

    test "assigns a store-scoped number and store currency" do
      po = PurchaseOrder.new(vendor: @vendor)
      result = CreatePurchaseOrder.call(
        purchase_order: po,
        lines_attributes: [ { product_variant_id: @variant.id, ordered_quantity: 3,
                               cost_entry_method: "discount_from_list", list_cost_cents: 1000, discount_bps: 1000 } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      assert_equal "001-PO-00003", result.purchase_order.purchase_order_number
      assert_equal "USD", result.purchase_order.currency_code
      assert_equal "draft", result.purchase_order.status
      assert_equal 900, result.purchase_order.purchase_order_lines.first.expected_unit_cost_cents
    end

    test "increments the store sequence across multiple purchase orders" do
      2.times do
        po = PurchaseOrder.new(vendor: @vendor)
        result = CreatePurchaseOrder.call(
          purchase_order: po,
          lines_attributes: [ { product_variant_id: @variant.id, ordered_quantity: 1,
                                 cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 500 } ],
          actor: @user,
          store: @store
        )
        assert result.success?, result.error
      end

      numbers = PurchaseOrder.where(store: @store).order(:purchase_order_number).pluck(:purchase_order_number)
      assert_equal %w[001-PO-00001 001-PO-00002 001-PO-00003 001-PO-00004], numbers
    end

    test "snapshots description, sku, and identifier from the variant" do
      po = PurchaseOrder.new(vendor: @vendor)
      result = CreatePurchaseOrder.call(
        purchase_order: po,
        lines_attributes: [ { product_variant_id: @variant.id, ordered_quantity: 1,
                               cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 500 } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      line = result.purchase_order.purchase_order_lines.first
      assert_equal @variant.name, line.description_snapshot
      assert_equal @variant.sku, line.sku_snapshot
      assert_equal @variant.product.identifier, line.identifier_snapshot
    end

    test "fails without at least one line" do
      po = PurchaseOrder.new(vendor: @vendor)
      result = CreatePurchaseOrder.call(purchase_order: po, lines_attributes: [], actor: @user, store: @store)

      assert_not result.success?
      assert_match(/at least one line/i, result.error)
    end

    test "defaults blank cost fields from the preferred vendor source, not selling price" do
      source = product_variant_vendors(:sample_book_ingram)
      assert_not_equal @variant.regular_price_cents, source.expected_unit_cost_cents

      po = PurchaseOrder.new(vendor: @vendor)
      result = CreatePurchaseOrder.call(
        purchase_order: po,
        lines_attributes: [ {
          product_variant_id: @variant.id,
          ordered_quantity: 2,
          cost_entry_method: "discount_from_list"
        } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      line = result.purchase_order.purchase_order_lines.first
      assert_equal source.id, line.product_variant_vendor_id
      assert_equal source.list_cost_cents, line.list_cost_cents
      assert_equal source.discount_bps, line.discount_bps
      assert_equal 720, line.expected_unit_cost_cents
      assert_not_equal @variant.regular_price_cents, line.expected_unit_cost_cents
      assert_equal "vendor_source", line.cost_provenance
    end

    test "keeps an explicitly entered zero discount instead of overwriting from the source" do
      source = product_variant_vendors(:sample_book_ingram)

      po = PurchaseOrder.new(vendor: @vendor)
      result = CreatePurchaseOrder.call(
        purchase_order: po,
        lines_attributes: [ {
          product_variant_id: @variant.id,
          product_variant_vendor_id: source.id,
          ordered_quantity: 1,
          cost_entry_method: "discount_from_list",
          list_cost_cents: source.list_cost_cents,
          discount_bps: 0
        } ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      line = result.purchase_order.purchase_order_lines.first
      assert_equal 0, line.discount_bps
      assert_equal source.list_cost_cents, line.expected_unit_cost_cents
    end
  end
end
