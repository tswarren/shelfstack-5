# frozen_string_literal: true

require "test_helper"

module Inventory
  class ConcurrencyPostReceiptTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      cleanup!
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @variant = product_variants(:sample_book_standard)

      membership = StoreMembership.find_by!(user: @clerk, store: @store)
      RolePermission.find_or_create_by!(
        role: membership.role,
        permission: Permission.find_by!(code: "inventory.receipt.post")
      )
      RolePermission.where(
        role: membership.role,
        permission: Permission.find_by!(code: "inventory.receipt.over_receive")
      ).delete_all

      po = PurchaseOrder.new(vendor: @vendor)
      created = Purchasing::CreatePurchaseOrder.call(
        purchase_order: po,
        lines_attributes: [ {
          product_variant_id: @variant.id, ordered_quantity: 5,
          cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 700
        } ],
        actor: @admin, store: @store
      )
      raise created.error unless created.success?
      placed = Purchasing::PlacePurchaseOrder.call(
        purchase_order: created.purchase_order, actor: @admin, store: @store
      )
      raise placed.error unless placed.success?
      @purchase_order = placed.purchase_order
      @po_line = @purchase_order.purchase_order_lines.first

      @receipt_a = build_receipt(accepted: 4)
      @receipt_b = build_receipt(accepted: 4)
    end

    teardown { cleanup! }

    test "concurrent receipts cannot both consume the same open quantity without over_receive" do
      results = {}
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:a] = PostReceipt.call(receipt: @receipt_a, actor: @clerk, store: @store)
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[:b] = PostReceipt.call(receipt: @receipt_b, actor: @clerk, store: @store)
          end
        end
      ]
      threads.each(&:join)

      successes = results.values.select(&:success?)
      failures = results.values.reject(&:success?)
      assert_equal 1, successes.size, results.transform_values { |r| [ r&.success?, r&.error ] }.inspect
      assert_equal 1, failures.size
      assert_match(/over-receive/i, failures.first.error)

      assert_equal 4, @po_line.reload.received_quantity
      assert_equal 1, Receipt.where(id: [ @receipt_a.id, @receipt_b.id ], status: "posted").count
    end

    private

    def build_receipt(accepted:)
      created = CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ {
          product_variant_id: @variant.id, purchase_order_line_id: @po_line.id,
          delivered_quantity: accepted, accepted_quantity: accepted,
          actual_unit_cost_cents: 700, cost_quality: "actual", cost_provenance: "manual_receipt"
        } ],
        actor: @admin, store: @store
      )
      raise created.error unless created.success?

      created.receipt
    end

    def cleanup!
      return unless defined?(@store)

      InventoryLedgerEntry.where(store_id: @store.id).delete_all
      InventoryReservation.where(store_id: @store.id).delete_all
      StockBalance.where(store_id: @store.id, product_variant_id: @variant&.id).delete_all

      if defined?(@receipt_a) || defined?(@receipt_b)
        ids = [ @receipt_a&.id, @receipt_b&.id ].compact
        ReceiptLine.where(receipt_id: ids).delete_all
        Receipt.where(id: ids).delete_all
      end

      if defined?(@purchase_order) && @purchase_order&.persisted?
        PurchaseOrderAllocationEvent.joins(:purchase_order_allocation)
          .where(purchase_order_allocations: { purchase_order_line_id: @purchase_order.purchase_order_lines.select(:id) })
          .delete_all
        PurchaseOrderAllocation.where(purchase_order_line_id: @purchase_order.purchase_order_lines.select(:id)).delete_all
        PurchaseOrderLine.where(purchase_order_id: @purchase_order.id).delete_all
        PurchaseOrder.where(id: @purchase_order.id).delete_all
      end
    end
  end
end
