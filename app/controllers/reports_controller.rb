# frozen_string_literal: true

# Phase 5g read-only Purchasing/Receiving/Requests operational views. These are
# projections over already-posted facts (purchase orders, receipts, product
# requests, allocation events) — never a new table, status, or workflow.
# Reporting consumes posted source records; it never modifies them (AGENTS.md §4).
class ReportsController < ApplicationController
  OnOrderRow = Data.define(:product_variant, :on_order_quantity)

  before_action :require_any_report_access!, only: %i[index]
  before_action -> { require_permission!("purchasing.purchase_order.view") }, only: %i[open_purchase_orders on_order allocation_events]
  before_action -> { require_permission!("inventory.receipt.view") }, only: %i[receiving_history]
  before_action -> { require_permission!("requests.product_request.view") }, only: %i[customer_requests]

  def index
    @can_view_purchase_orders = Current.user.can?("purchasing.purchase_order.view", store: Current.store)
    @can_view_receipts = Current.user.can?("inventory.receipt.view", store: Current.store)
    @can_view_requests = Current.user.can?("requests.product_request.view", store: Current.store)
  end

  def open_purchase_orders
    scope = Current.store.purchase_orders.where(status: %w[draft ordered])
      .includes(:vendor, :purchase_order_lines).order(created_at: :desc)
    @pagy, @purchase_orders = pagy(scope, limit: pagy_limit)
    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store)
  end

  def on_order
    variant_ids = PurchaseOrderLine.joins(:purchase_order)
      .where(purchase_orders: { store_id: Current.store.id, status: "ordered" })
      .distinct.pluck(:product_variant_id)
    variants = ProductVariant.where(id: variant_ids).includes(:product)

    @rows = variants.map { |variant| OnOrderRow.new(variant, Purchasing::OnOrder.call(store: Current.store, product_variant: variant)) }
      .select { |row| row.on_order_quantity.positive? }
      .sort_by { |row| -row.on_order_quantity }
  end

  def receiving_history
    receipt_scope = Current.store.receipts.includes(:vendor).order(created_at: :desc)
    @pagy, @receipts = pagy(receipt_scope, limit: pagy_limit)
    @can_view_cost = Current.user.can?("inventory.cost.view", store: Current.store) ||
      Current.user.can?("purchasing.cost.view", store: Current.store)

    return unless Current.user.can?("purchasing.purchase_order.view", store: Current.store)

    @partially_received_orders = Current.store.purchase_orders.where(status: "ordered")
      .includes(:vendor, :purchase_order_lines)
      .select { |po| po.receiving_state == "partially_received" }
  end

  def customer_requests
    scope = Current.store.product_requests.where(request_type: "customer_request")
      .includes(:product, :product_variant).order(created_at: :desc)
    @pagy, @product_requests = pagy(scope, limit: pagy_limit)
  end

  def allocation_events
    scope = PurchaseOrderAllocationEvent
      .joins(purchase_order_allocation: { purchase_order_line: :purchase_order })
      .where(purchase_orders: { store_id: Current.store.id })
      .includes(purchase_order_allocation: [ :product_request, { purchase_order_line: [ :product_variant, :purchase_order ] } ], user: [])
      .order(occurred_at: :desc, id: :desc)
    @pagy, @events = pagy(scope, limit: pagy_limit)
  end

  private

  def require_any_report_access!
    allowed = %w[purchasing.purchase_order.view inventory.receipt.view requests.product_request.view].any? do |key|
      Current.user.can?(key, store: Current.store)
    end
    return if allowed

    redirect_to root_path, alert: "You are not authorized to perform that action."
  end
end
