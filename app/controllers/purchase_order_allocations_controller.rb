# frozen_string_literal: true

# Minimal allocate/release surface reachable from a Purchase Order's show
# page or a Customer Request's show page (docs/implementation/service-catalog.md
# Phase 5e). `redirect_target` selects where to return; unrecognized values
# fall back to the safest available record.
class PurchaseOrderAllocationsController < ApplicationController
  before_action -> { require_permission!("purchasing.allocation.create") }, only: %i[create]
  before_action -> { require_permission!("purchasing.allocation.release") }, only: %i[release]
  before_action :set_purchase_order_allocation, only: %i[release]

  def create
    line = PurchaseOrderLine.joins(:purchase_order)
      .where(purchase_orders: { store_id: Current.store.id })
      .find_by(id: params.dig(:purchase_order_allocation, :purchase_order_line_id))
    product_request = Current.store.product_requests.find_by(id: params.dig(:purchase_order_allocation, :product_request_id))
    if line.blank? || product_request.blank?
      fallback = line&.purchase_order || product_request || purchase_orders_path
      return redirect_to fallback, alert: "Select both a purchase order line and a product request."
    end

    result = Purchasing::CreateAllocation.call(
      purchase_order_line: line,
      product_request: product_request,
      quantity: params.dig(:purchase_order_allocation, :quantity),
      actor: Current.user,
      store: Current.store
    )

    target = redirect_target(default_line: line, default_product_request: product_request)
    if result.success?
      redirect_to target, notice: "Allocation created."
    else
      redirect_to target, alert: result.error
    end
  end

  def release
    result = Purchasing::ReleaseAllocation.call(
      purchase_order_allocation: @purchase_order_allocation,
      quantity: params.dig(:purchase_order_allocation, :quantity),
      reason: params.dig(:purchase_order_allocation, :reason),
      note: params.dig(:purchase_order_allocation, :note),
      actor: Current.user,
      store: Current.store
    )

    target = redirect_target(
      default_line: @purchase_order_allocation.purchase_order_line,
      default_product_request: @purchase_order_allocation.product_request
    )
    if result.success?
      redirect_to target, notice: "Allocation released."
    else
      redirect_to target, alert: result.error
    end
  end

  private

  def set_purchase_order_allocation
    @purchase_order_allocation = PurchaseOrderAllocation.joins(purchase_order_line: :purchase_order)
      .where(purchase_orders: { store_id: Current.store.id }).find(params[:id])
  end

  def redirect_target(default_line:, default_product_request:)
    if params[:redirect_target] == "purchase_order"
      default_line.purchase_order
    else
      default_product_request
    end
  end
end
