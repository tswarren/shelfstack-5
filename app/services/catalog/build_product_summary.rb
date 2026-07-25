# frozen_string_literal: true

module Catalog
  # Read-only Product summary hub aggregation for a selected Store (Gate 8d /
  # OD-P8-08). Catalog owns presentation aggregation only — stock, POs,
  # receipts, requests, and vendor sources remain domain-owned reads.
  # Permission gates prevent querying unauthorized datasets.
  class BuildProductSummary < ApplicationService
    UNIT_STATUSES = InventoryUnit::STATUSES

    Capabilities = Data.define(
      :stock_view, :inventory_cost_view, :receipt_view, :inventory_unit_manage,
      :purchase_order_view, :purchasing_cost_view, :vendor_source_view, :vendor_view,
      :request_view
    )

    StockSummary = Data.define(
      :tracking_mode,
      :on_hand, :reserved, :unavailable, :available, :on_order,
      :unit_status_counts,
      :stock_balance_id,
      :moving_average_cost_cents,
      :cost_quality,
      :last_received_at
    )

    CreatorRow = Data.define(:id, :display_name, :role, :credited_as, :position)

    Identity = Data.define(
      :name, :subtitle, :identifier, :alternate_identifier, :product_type,
      :product_format_name, :status, :sellable,
      :publisher_or_manufacturer_name, :imprint_or_brand_name,
      :publication_date, :language_code, :edition_statement,
      :description, :identifier_warning, :creators
    )

    StandardItem = Data.define(
      :id, :sku, :name, :status, :regular_price_cents, :inventory_tracking_mode,
      :sellable, :purchasable, :effective_values
    )

    Attention = Data.define(:identifier_warning, :missing_standard_item, :eligibility_blockers)

    OpenPoLine = Data.define(
      :id, :purchase_order_id, :purchase_order_number, :open_quantity, :ordered_quantity
    )

    RecentReceiptLine = Data.define(
      :id, :receipt_id, :receipt_number, :accepted_quantity, :posted_at
    )

    RequestRow = Data.define(
      :id, :request_type, :status, :priority, :requested_quantity,
      :assigned_buyer_name, :resolution,
      :fulfilled_quantity, :active_reserved_quantity, :remaining_allocated_quantity,
      :outstanding_quantity, :uncovered_quantity, :customer_request
    )

    VendorSourceRow = Data.define(
      :id, :vendor_id, :vendor_name, :vendor_item_code, :preferred,
      :expected_unit_cost_cents, :minimum_order_quantity, :order_multiple
    )

    StoreInfo = Data.define(:id, :name)

    StoreOperations = Data.define(:open_po_lines, :recent_receipt_lines, :open_requests)

    Summary = Data.define(
      :product, :store, :capabilities, :attention, :identity,
      :standard_item, :stock, :store_operations, :vendor_sources
    )

    def initialize(product:, store:, actor:)
      @product = product
      @store = store
      @actor = actor
    end

    def call
      caps = capabilities
      variant = @product.product_variants.order(:id).first
      missing_item = variant.nil?
      # SaleEligibility once for the hub — Attention presents blockers; Standard
      # Item does not duplicate the same fact until a section needs it.
      blockers = missing_item ? [] : sale_eligibility_blockers(variant)

      Summary.new(
        product: @product,
        store: StoreInfo.new(id: @store.id, name: @store.name),
        capabilities: caps,
        attention: build_attention(missing_item, blockers),
        identity: build_identity,
        standard_item: missing_item ? nil : build_standard_item(variant),
        stock: missing_item ? nil : build_stock(variant, caps),
        store_operations: missing_item ? empty_store_operations : build_store_operations(variant, caps),
        vendor_sources: missing_item || !caps.vendor_source_view ? [] : build_vendor_sources(variant, caps)
      )
    end

    private

    def capabilities
      Capabilities.new(
        stock_view: permitted?("inventory.stock.view"),
        inventory_cost_view: permitted?("inventory.cost.view"),
        receipt_view: permitted?("inventory.receipt.view"),
        inventory_unit_manage: permitted?("inventory.unit.manage"),
        purchase_order_view: permitted?("purchasing.purchase_order.view"),
        purchasing_cost_view: permitted?("purchasing.cost.view"),
        vendor_source_view: permitted?("purchasing.vendor_source.view"),
        vendor_view: permitted?("purchasing.vendor.view"),
        request_view: permitted?("requests.product_request.view")
      )
    end

    def permitted?(key)
      Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: key
      ) == :allow
    end

    def sale_eligibility_blockers(variant)
      Catalog::SaleEligibility.call(variant: variant, store: @store).blockers
    end

    def build_attention(missing_item, blockers)
      Attention.new(
        identifier_warning: @product.identifier_warning,
        missing_standard_item: missing_item,
        eligibility_blockers: blockers
      )
    end

    def build_identity
      creators = @product.product_creators.includes(:creator).order(:position, :id).map do |pc|
        CreatorRow.new(
          id: pc.creator_id,
          display_name: pc.creator.display_name,
          role: pc.role,
          credited_as: pc.credited_as,
          position: pc.position
        )
      end

      Identity.new(
        name: @product.name,
        subtitle: @product.subtitle,
        identifier: @product.identifier,
        alternate_identifier: @product.alternate_identifier,
        product_type: @product.product_type,
        product_format_name: @product.product_format&.name,
        status: @product.status,
        sellable: @product.sellable,
        publisher_or_manufacturer_name: @product.publisher_or_manufacturer_name,
        imprint_or_brand_name: @product.imprint_or_brand_name,
        publication_date: @product.publication_date,
        language_code: @product.language_code,
        edition_statement: @product.edition_statement,
        description: @product.description,
        identifier_warning: @product.identifier_warning,
        creators: creators
      )
    end

    def build_standard_item(variant)
      effective = Catalog::ResolveEffectiveValues.call(product: @product, variant: variant)

      StandardItem.new(
        id: variant.id,
        sku: variant.sku,
        name: variant.name,
        status: variant.status,
        regular_price_cents: variant.regular_price_cents,
        inventory_tracking_mode: variant.inventory_tracking_mode,
        sellable: variant.sellable,
        purchasable: variant.purchasable,
        effective_values: effective
      )
    end

    def build_stock(variant, caps)
      mode = variant.inventory_tracking_mode
      last_received = caps.receipt_view ? last_received_at(variant) : nil

      case mode
      when "quantity"
        return nil unless caps.stock_view

        build_quantity_stock(variant, caps, last_received)
      when "individual"
        return nil unless caps.stock_view

        build_individual_stock(variant, caps, last_received)
      when "none"
        return nil unless caps.stock_view || caps.receipt_view

        StockSummary.new(
          tracking_mode: "none",
          on_hand: nil, reserved: nil, unavailable: nil, available: nil, on_order: nil,
          unit_status_counts: nil,
          stock_balance_id: nil,
          moving_average_cost_cents: nil,
          cost_quality: nil,
          last_received_at: last_received
        )
      else
        nil
      end
    end

    def build_quantity_stock(variant, caps, last_received)
      # Read StockBalance directly — do not use ReplenishmentSnapshot here; it
      # always queries OnOrder and preferred vendor-source cost even when those
      # capabilities are absent.
      balance = StockBalance.find_by(store_id: @store.id, product_variant_id: variant.id)
      on_order = if caps.purchase_order_view
        Purchasing::OnOrder.call(store: @store, product_variant: variant)
      end

      StockSummary.new(
        tracking_mode: "quantity",
        on_hand: balance&.on_hand || 0,
        reserved: balance&.reserved || 0,
        unavailable: balance&.unavailable || 0,
        available: balance&.available || 0,
        on_order: on_order,
        unit_status_counts: nil,
        stock_balance_id: balance&.id,
        moving_average_cost_cents: caps.inventory_cost_view ? balance&.moving_average_cost_cents : nil,
        cost_quality: caps.inventory_cost_view ? balance&.cost_quality : nil,
        last_received_at: last_received
      )
    end

    def build_individual_stock(variant, caps, last_received)
      counts = UNIT_STATUSES.index_with { 0 }
      InventoryUnit.where(store_id: @store.id, product_variant_id: variant.id)
        .group(:status).count.each { |status, count| counts[status] = count }

      on_order = if caps.purchase_order_view
        Purchasing::OnOrder.call(store: @store, product_variant: variant)
      end

      StockSummary.new(
        tracking_mode: "individual",
        on_hand: nil, reserved: nil, unavailable: nil, available: nil,
        on_order: on_order,
        unit_status_counts: counts,
        stock_balance_id: nil,
        moving_average_cost_cents: nil,
        cost_quality: nil,
        last_received_at: last_received
      )
    end

    def last_received_at(variant)
      ReceiptLine
        .joins(:receipt)
        .where(
          product_variant_id: variant.id,
          receipts: { store_id: @store.id, status: "posted" }
        )
        .where("receipt_lines.accepted_quantity > 0")
        .order("receipts.posted_at DESC", "receipts.id DESC", "receipt_lines.id DESC")
        .limit(1)
        .pick("receipts.posted_at")
    end

    def empty_store_operations
      StoreOperations.new(open_po_lines: [], recent_receipt_lines: [], open_requests: [])
    end

    def build_store_operations(variant, caps)
      StoreOperations.new(
        open_po_lines: caps.purchase_order_view ? open_po_lines(variant) : [],
        recent_receipt_lines: caps.receipt_view ? recent_receipt_lines(variant) : [],
        open_requests: caps.request_view ? open_requests(variant) : []
      )
    end

    def open_po_lines(variant)
      PurchaseOrderLine
        .includes(:purchase_order)
        .joins(:purchase_order)
        .where(product_variant_id: variant.id, purchase_orders: { store_id: @store.id, status: "ordered" })
        .where(
          "purchase_order_lines.ordered_quantity - " \
          "purchase_order_lines.received_quantity - " \
          "purchase_order_lines.cancelled_quantity > 0"
        )
        .order("purchase_orders.ordered_at DESC NULLS LAST", "purchase_orders.id DESC", :id)
        .limit(8)
        .map do |line|
          OpenPoLine.new(
            id: line.id,
            purchase_order_id: line.purchase_order_id,
            purchase_order_number: line.purchase_order.purchase_order_number,
            open_quantity: line.open_quantity,
            ordered_quantity: line.ordered_quantity
          )
        end
    end

    def recent_receipt_lines(variant)
      ReceiptLine
        .includes(:receipt)
        .joins(:receipt)
        .where(
          product_variant_id: variant.id,
          receipts: { store_id: @store.id, status: "posted" }
        )
        .where("receipt_lines.accepted_quantity > 0")
        .order("receipts.posted_at DESC", "receipts.id DESC", "receipt_lines.id DESC")
        .limit(5)
        .map do |line|
          RecentReceiptLine.new(
            id: line.id,
            receipt_id: line.receipt_id,
            receipt_number: line.receipt.receipt_number,
            accepted_quantity: line.accepted_quantity,
            posted_at: line.receipt.posted_at
          )
        end
    end

    def open_requests(variant)
      requests = ProductRequest
        .open_requests
        .includes(:assigned_buyer_user)
        .where(store_id: @store.id, product_id: @product.id)
        .where("product_variant_id IS NULL OR product_variant_id = ?", variant.id)
        .order(:id)
        .limit(20)
        .to_a

      customer_requests = requests.select(&:customer_request?)
      coverage = request_coverage_by_id(customer_requests)
      requests.map { |request| request_row(request, coverage[request.id]) }
    end

    def request_row(request, coverage)
      customer = request.customer_request?
      RequestRow.new(
        id: request.id,
        request_type: request.request_type,
        status: request.status,
        priority: request.priority,
        requested_quantity: request.requested_quantity,
        assigned_buyer_name: request.assigned_buyer_user&.username,
        resolution: request.resolution,
        fulfilled_quantity: customer ? coverage.fetch(:fulfilled) : nil,
        active_reserved_quantity: customer ? coverage.fetch(:reserved) : nil,
        remaining_allocated_quantity: customer ? coverage.fetch(:allocated) : nil,
        outstanding_quantity: customer ? coverage.fetch(:outstanding) : nil,
        uncovered_quantity: customer ? coverage.fetch(:uncovered) : nil,
        customer_request: customer
      )
    end

    # Batched coverage for customer requests — constant queries across selected
    # IDs (matches ProductRequest coverage formulas without per-request N+1).
    def request_coverage_by_id(customer_requests)
      return {} if customer_requests.empty?

      request_ids = customer_requests.map(&:id)
      fulfilled = fulfilled_quantity_by_request_id(request_ids)
      reserved = active_reserved_quantity_by_request_id(request_ids)
      allocated = remaining_allocated_quantity_by_request_id(request_ids)

      customer_requests.each_with_object({}) do |request, map|
        f = fulfilled.fetch(request.id, 0)
        r = reserved.fetch(request.id, 0)
        a = allocated.fetch(request.id, 0)
        map[request.id] = {
          fulfilled: f,
          reserved: r,
          allocated: a,
          outstanding: [ request.requested_quantity - f, 0 ].max,
          uncovered: [ request.requested_quantity - f - r - a, 0 ].max
        }
      end
    end

    def fulfilled_quantity_by_request_id(request_ids)
      rows = ProductRequestFulfillment
        .where(product_request_id: request_ids)
        .group(:product_request_id, :kind)
        .sum(:quantity)

      request_ids.index_with do |id|
        rows.fetch([ id, "fulfill" ], 0) - rows.fetch([ id, "reverse" ], 0)
      end
    end

    def active_reserved_quantity_by_request_id(request_ids)
      request_held = InventoryReservation.active
        .where(source_type: "product_request", source_id: request_ids)
        .group(:source_id)
        .sum(:quantity)

      pos_held = InventoryReservation.active
        .where(source_type: "pos_line_item")
        .joins("INNER JOIN pos_line_items ON pos_line_items.id = inventory_reservations.source_id")
        .where(pos_line_items: { product_request_id: request_ids, status: "pending" })
        .group("pos_line_items.product_request_id")
        .sum("inventory_reservations.quantity")

      request_ids.index_with do |id|
        request_held.fetch(id, 0) + pos_held.fetch(id, 0)
      end
    end

    def remaining_allocated_quantity_by_request_id(request_ids)
      allocations = PurchaseOrderAllocation
        .where(product_request_id: request_ids)
        .includes(:purchase_order_allocation_events)

      totals = Hash.new(0)
      allocations.each do |allocation|
        events = allocation.purchase_order_allocation_events
        converted = events.select { |e| e.event_type == "converted_to_reservation" }.sum(&:quantity)
        released = events.select { |e| e.event_type == "released" }.sum(&:quantity)
        totals[allocation.product_request_id] += [ allocation.quantity - converted - released, 0 ].max
      end
      totals
    end

    def build_vendor_sources(variant, caps)
      ProductVariantVendor
        .includes(:vendor)
        .where(product_variant_id: variant.id, active: true)
        .order(preferred: :desc, id: :asc)
        .map do |source|
          VendorSourceRow.new(
            id: source.id,
            vendor_id: source.vendor_id,
            vendor_name: source.vendor.name,
            vendor_item_code: source.vendor_item_code,
            preferred: source.preferred,
            expected_unit_cost_cents: caps.purchasing_cost_view ? source.expected_unit_cost_cents : nil,
            minimum_order_quantity: source.minimum_order_quantity,
            order_multiple: source.order_multiple
          )
        end
    end
  end
end
