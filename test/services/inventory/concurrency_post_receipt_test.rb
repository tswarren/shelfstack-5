# frozen_string_literal: true

require "test_helper"

module Inventory
  class ConcurrencyPostReceiptTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @variant = product_variants(:sample_book_standard)
      @membership = StoreMembership.find_by!(user: @clerk, store: @store)
      @role = @membership.role

      @post_perm = Permission.find_by!(code: "inventory.receipt.post")
      @over_perm = Permission.find_by!(code: "inventory.receipt.over_receive")
      @had_post = RolePermission.exists?(role: @role, permission: @post_perm)
      @had_over = RolePermission.exists?(role: @role, permission: @over_perm)
      RolePermission.find_or_create_by!(role: @role, permission: @post_perm)
      RolePermission.where(role: @role, permission: @over_perm).delete_all

      @created_receipt_ids = []
      @created_po_ids = []

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
      @created_po_ids << @purchase_order.id

      @receipt_a = build_receipt(accepted: 4)
      @receipt_b = build_receipt(accepted: 4)
    end

    teardown do
      PostReceipt.before_po_line_lock = nil
      cleanup_created!
      restore_permissions!
    end

    test "concurrent receipts cannot both consume the same open quantity without over_receive" do
      start_gate = Queue.new
      results = {}

      # Both threads wait here so PostReceipt calls overlap on the PO lock.
      PostReceipt.before_po_line_lock = lambda {
        # After PO lock is held by the first thread, the second blocks on PO.lock.
        # No-op hook kept for future lock-point probes.
      }

      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            start_gate.pop
            results[:a] = PostReceipt.call(receipt: @receipt_a, actor: @clerk, store: @store)
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            start_gate.pop
            results[:b] = PostReceipt.call(receipt: @receipt_b, actor: @clerk, store: @store)
          end
        end
      ]
      start_gate << true
      start_gate << true
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

      @created_receipt_ids << created.receipt.id
      created.receipt
    end

    def cleanup_created!
      line_ids = ReceiptLine.where(receipt_id: @created_receipt_ids).pluck(:id)
      InventoryLedgerEntry.where(source_type: "ReceiptLine", source_id: line_ids).delete_all
      ReceiptLine.where(id: line_ids).delete_all
      Receipt.where(id: @created_receipt_ids).delete_all

      PurchaseOrder.where(id: @created_po_ids).find_each do |po|
        po_line_ids = po.purchase_order_lines.pluck(:id)
        PurchaseOrderAllocationEvent.joins(:purchase_order_allocation)
          .where(purchase_order_allocations: { purchase_order_line_id: po_line_ids }).delete_all
        PurchaseOrderAllocation.where(purchase_order_line_id: po_line_ids).delete_all
        PurchaseOrderLine.where(id: po_line_ids).delete_all
        po.delete
      end

      StockBalance.where(store: @store, product_variant: @variant).delete_all
    end

    def restore_permissions!
      if @had_post
        RolePermission.find_or_create_by!(role: @role, permission: @post_perm)
      else
        RolePermission.where(role: @role, permission: @post_perm).delete_all
      end

      if @had_over
        RolePermission.find_or_create_by!(role: @role, permission: @over_perm)
      else
        RolePermission.where(role: @role, permission: @over_perm).delete_all
      end
    end
  end
end
