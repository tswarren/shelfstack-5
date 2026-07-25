# frozen_string_literal: true

require "test_helper"

module Catalog
  class BuildProductSummaryTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @other_store = stores(:warehouse)
      @admin = users(:admin)
      @product = products(:sample_book)
      @variant = product_variants(:sample_book_standard)
      @individual_product = products(:signed_book)
      @individual_variant = product_variants(:signed_book_standard)
      @none_product = products(:gift_wrap_service)
      @none_variant = product_variants(:gift_wrap_service_standard)
    end

    test "quantity tracking uses stock balance quantities without leaking vendor expected cost into stock" do
      balance = StockBalance.create!(
        store: @store, product_variant: @variant, on_hand: 12, reserved: 2, unavailable: 1,
        inventory_value_cents: 8400, moving_average_cost_cents: 700, cost_quality: "actual"
      )

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin)

      assert_equal "quantity", summary.stock.tracking_mode
      assert_equal 12, summary.stock.on_hand
      assert_equal 9, summary.stock.available
      assert_equal balance.id, summary.stock.stock_balance_id
      assert_equal 700, summary.stock.moving_average_cost_cents
      assert_nil summary.stock.unit_status_counts
      assert summary.vendor_sources.any?
      assert_equal product_variant_vendors(:sample_book_ingram).expected_unit_cost_cents,
                   summary.vendor_sources.first.expected_unit_cost_cents
    end

    test "individual tracking uses unit status counts and does not report false zero stock balance" do
      Inventory::CreateInventoryUnit.call(
        store: @store, product_variant: @individual_variant, actor: @admin, acquisition_cost_cents: 1000
      )
      unit = InventoryUnit.where(product_variant: @individual_variant, store: @store).last
      unit.update!(status: "reserved")

      summary = BuildProductSummary.call(product: @individual_product, store: @store, actor: @admin)

      assert_equal "individual", summary.stock.tracking_mode
      assert_nil summary.stock.on_hand
      assert_nil summary.stock.stock_balance_id
      assert_nil summary.stock.moving_average_cost_cents
      assert_equal 1, summary.stock.unit_status_counts["reserved"]
      assert_equal 0, summary.stock.unit_status_counts["available"]
    end

    test "none tracking omits inventory quantities and on-order" do
      summary = BuildProductSummary.call(product: @none_product, store: @store, actor: @admin)

      assert_equal "none", summary.stock.tracking_mode
      assert_nil summary.stock.on_hand
      assert_nil summary.stock.on_order
      assert_nil summary.stock.unit_status_counts
    end

    test "missing standard variant does not raise and sets attention" do
      service = Catalog::CreateProduct.new(
        organization: organizations(:acme),
        actor: @admin,
        store: @store,
        identifier: "",
        product_attrs: {
          name: "No Variant Hub Product",
          product_type: "book",
          product_format_id: product_formats(:paperback).id,
          status: "active",
          sellable: false
        },
        variant_attrs: {
          name: "Standard",
          inventory_tracking_mode: "quantity",
          status: "active",
          sellable: false,
          purchasable: false
        }
      )
      assert service.call, service.product&.errors&.full_messages&.to_sentence
      product = service.product
      product.product_variants.destroy_all

      summary = BuildProductSummary.call(product: product.reload, store: @store, actor: @admin)

      assert summary.attention.missing_standard_item
      assert_nil summary.standard_item
      assert_nil summary.stock
      assert_empty summary.vendor_sources
    end

    test "last received ignores draft receipts other stores and zero-accepted lines" do
      posted = create_posted_receipt!(store: @store, variant: @variant, accepted: 2, posted_at: 2.days.ago)
      create_posted_receipt!(store: @store, variant: @variant, accepted: 0, delivered: 3, rejected: 3, posted_at: 1.day.ago)
      create_draft_receipt!(store: @store, variant: @variant)
      create_posted_receipt!(store: @other_store, variant: @variant, accepted: 5, posted_at: Time.current)

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin)

      assert_in_delta posted.posted_at.to_i, summary.stock.last_received_at.to_i, 1
    end

    test "vendor sources are returned as organization-wide data separate from store ops" do
      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin)

      assert summary.vendor_sources.any?
      assert_equal "Ingram Book Company", summary.vendor_sources.first.vendor_name
      assert_kind_of Array, summary.store_operations.open_po_lines
      assert_kind_of Array, summary.store_operations.open_requests
    end

    test "stock dataset is absent without inventory.stock.view" do
      RolePermission.where(role: roles(:administrator), permission: permissions(:inventory_stock_view)).delete_all
      StockBalance.create!(
        store: @store, product_variant: @variant, on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: nil
      )

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin.reload)

      assert_nil summary.stock
      assert_not summary.capabilities.stock_view
    end

    test "inventory cost and purchasing cost permissions are independent" do
      StockBalance.create!(
        store: @store, product_variant: @variant, on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 3500, moving_average_cost_cents: 700, cost_quality: "actual"
      )
      RolePermission.where(role: roles(:administrator), permission: permissions(:inventory_cost_view)).delete_all

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin.reload)

      assert_nil summary.stock.moving_average_cost_cents
      assert_equal product_variant_vendors(:sample_book_ingram).expected_unit_cost_cents,
                   summary.vendor_sources.first.expected_unit_cost_cents

      RolePermission.find_or_create_by!(role: roles(:administrator), permission: permissions(:inventory_cost_view))
      RolePermission.where(role: roles(:administrator), permission: permissions(:purchasing_cost_view)).delete_all

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin.reload)
      assert_equal 700, summary.stock.moving_average_cost_cents
      assert_nil summary.vendor_sources.first.expected_unit_cost_cents
    end

    test "domain datasets are absent when their view permissions are missing" do
      RolePermission.where(role: roles(:administrator), permission: permissions(:purchasing_purchase_order_view)).delete_all
      RolePermission.where(role: roles(:administrator), permission: permissions(:inventory_receipt_view)).delete_all
      RolePermission.where(role: roles(:administrator), permission: permissions(:requests_product_request_view)).delete_all
      RolePermission.where(role: roles(:administrator), permission: permissions(:purchasing_vendor_source_view)).delete_all

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin.reload)

      assert_empty summary.store_operations.open_po_lines
      assert_empty summary.store_operations.recent_receipt_lines
      assert_empty summary.store_operations.open_requests
      assert_empty summary.vendor_sources
      assert_nil summary.stock&.on_order
    end

    test "customer request coverage uses ProductRequest methods" do
      request = product_requests(:open_customer_request)
      assert_equal @product.id, request.product_id

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin)
      row = summary.store_operations.open_requests.find { |r| r.id == request.id }

      assert row
      assert row.customer_request
      assert_equal request.requested_quantity, row.requested_quantity
      assert_equal request.fulfilled_quantity, row.fulfilled_quantity
      assert_equal request.outstanding_quantity, row.outstanding_quantity
      assert_equal request.uncovered_quantity, row.uncovered_quantity
    end

    test "building the summary changes no record counts or timestamps" do
      before_product = @product.reload.updated_at
      before_counts = [
        Product.count, ProductVariant.count, StockBalance.count, CatalogEnrichmentEvent.count,
        ProductVariantVendor.count, ProductRequest.count
      ]

      BuildProductSummary.call(product: @product, store: @store, actor: @admin)

      assert_equal before_counts, [
        Product.count, ProductVariant.count, StockBalance.count, CatalogEnrichmentEvent.count,
        ProductVariantVendor.count, ProductRequest.count
      ]
      assert_equal before_product.to_i, @product.reload.updated_at.to_i
    end

    test "selected-store isolation for open requests" do
      ProductRequest.create!(
        store: @other_store,
        request_type: "staff_suggestion",
        status: "open",
        product: @product,
        product_variant: @variant,
        requested_quantity: 9,
        priority: "normal",
        requested_by_user: @admin
      )

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin)
      assert summary.store_operations.open_requests.none? { |r| r.requested_quantity == 9 }
    end

    test "open PO list includes an older open line when newer lines are fully resolved" do
      older = PurchaseOrder.create!(
        store: @store,
        vendor: vendors(:acme_distributor),
        purchase_order_number: "HUB-PO-OLD-#{SecureRandom.hex(3)}",
        status: "ordered",
        currency_code: "USD",
        ordered_on: 30.days.ago.to_date,
        ordered_at: 30.days.ago,
        ordered_by_user: @admin
      )
      older_line = older.purchase_order_lines.create!(
        position: 0,
        product_variant: @variant,
        product_variant_vendor: product_variant_vendors(:sample_book_ingram),
        description_snapshot: @variant.name,
        identifier_snapshot: @product.identifier,
        sku_snapshot: @variant.sku,
        ordered_quantity: 4,
        cancelled_quantity: 0,
        received_quantity: 0,
        cost_entry_method: "direct_net_cost",
        expected_unit_cost_cents: 700,
        cost_provenance: "manual_entry"
      )

      21.times do |i|
        po = PurchaseOrder.create!(
          store: @store,
          vendor: vendors(:acme_distributor),
          purchase_order_number: "HUB-PO-NEW-#{i}-#{SecureRandom.hex(2)}",
          status: "ordered",
          currency_code: "USD",
          ordered_on: (i + 1).days.ago.to_date,
          ordered_at: (i + 1).hours.ago,
          ordered_by_user: @admin
        )
        po.purchase_order_lines.create!(
          position: 0,
          product_variant: @variant,
          product_variant_vendor: product_variant_vendors(:sample_book_ingram),
          description_snapshot: @variant.name,
          identifier_snapshot: @product.identifier,
          sku_snapshot: @variant.sku,
          ordered_quantity: 2,
          cancelled_quantity: 0,
          received_quantity: 2,
          cost_entry_method: "direct_net_cost",
          expected_unit_cost_cents: 700,
          cost_provenance: "manual_entry"
        )
      end

      summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin)
      open_ids = summary.store_operations.open_po_lines.map(&:id)

      assert_includes open_ids, older_line.id
      assert summary.store_operations.open_po_lines.any? { |line| line.open_quantity.positive? }
    end

    test "customer request coverage uses a bounded query count across many requests" do
      10.times do |i|
        ProductRequest.create!(
          store: @store,
          request_type: "customer_request",
          status: "open",
          product: @product,
          product_variant: @variant,
          requested_quantity: i + 1,
          priority: "normal",
          requested_by_user: @admin,
          customer_reference: "HUB-COV-#{i}"
        )
      end

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql].to_s
        next if payload[:name] == "SCHEMA"
        next if sql.match?(/\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

        queries << sql
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        BuildProductSummary.call(product: @product, store: @store, actor: @admin)
      end

      coverage_queries = queries.count do |sql|
        sql.match?(/product_request_fulfillments|inventory_reservations|purchase_order_allocations/i)
      end

      assert_operator coverage_queries, :<=, 6,
                      "expected batched request coverage, got #{coverage_queries} related queries:\n#{queries.grep(/product_request_fulfillments|inventory_reservations|purchase_order_allocations/i).join("\n")}"
    end

    test "quantity stock without purchase_order_view does not query OnOrder or vendor sources" do
      StockBalance.create!(
        store: @store, product_variant: @variant, on_hand: 3, reserved: 0, unavailable: 0,
        inventory_value_cents: nil
      )
      RolePermission.where(role: roles(:administrator), permission: permissions(:purchasing_purchase_order_view)).delete_all
      RolePermission.where(role: roles(:administrator), permission: permissions(:purchasing_vendor_source_view)).delete_all
      RolePermission.where(role: roles(:administrator), permission: permissions(:purchasing_cost_view)).delete_all

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql].to_s
        next if payload[:name] == "SCHEMA"
        next if sql.match?(/\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

        queries << sql
      end

      summary = nil
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        summary = BuildProductSummary.call(product: @product, store: @store, actor: @admin.reload)
      end

      assert_equal 3, summary.stock.on_hand
      assert_nil summary.stock.on_order
      assert_empty summary.vendor_sources
      assert queries.none? { |sql| sql.match?(/FROM ["`]?product_variant_vendors["`]?/i) },
             "stock path must not query vendor sources without permission"
      assert queries.none? { |sql| sql.match?(/FROM ["`]?purchase_order_lines["`]?/i) },
             "stock path must not query purchase order lines without PO permission"
    end

    private

    def create_posted_receipt!(store:, variant:, accepted:, posted_at:, delivered: nil, rejected: 0)
      delivered ||= accepted + rejected
      # Lines may only be created while the parent Receipt is draft.
      receipt = Receipt.create!(
        store: store,
        vendor: vendors(:acme_distributor),
        receipt_number: "HUB-#{SecureRandom.hex(4)}",
        status: "draft",
        received_by_user: @admin
      )
      attrs = {
        receipt: receipt,
        position: 0,
        product_variant: variant,
        delivered_quantity: delivered,
        accepted_quantity: accepted,
        rejected_quantity: rejected,
        accepted_unavailable_quantity: 0
      }
      if accepted.positive?
        attrs.merge!(
          actual_unit_cost_cents: 700,
          cost_quality: "actual",
          cost_provenance: "manual_receipt"
        )
      end
      ReceiptLine.create!(attrs)
      receipt.update_columns(
        status: "posted",
        posted_at: posted_at,
        posted_by_user_id: @admin.id
      )
      receipt
    end

    def create_draft_receipt!(store:, variant:)
      receipt = Receipt.create!(
        store: store,
        vendor: vendors(:acme_distributor),
        receipt_number: "HUB-DRAFT-#{SecureRandom.hex(3)}",
        status: "draft"
      )
      ReceiptLine.create!(
        receipt: receipt,
        position: 0,
        product_variant: variant,
        delivered_quantity: 1,
        accepted_quantity: 1,
        rejected_quantity: 0,
        accepted_unavailable_quantity: 0,
        actual_unit_cost_cents: 700,
        cost_quality: "actual",
        cost_provenance: "manual_receipt"
      )
      receipt
    end
  end
end
