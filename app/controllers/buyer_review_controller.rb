# frozen_string_literal: true

# Buyer-review queue: a projection over open Product Requests
# (ordering-and-acquisition-planning.md §2.4). Not a table, PO-line flag, or
# inventory quantity — purely a read model plus the seam that lets a buyer add
# demand to a draft Purchase Order.
class BuyerReviewController < ApplicationController
  before_action -> { require_permission!("requests.product_request.view") }, only: %i[index]
  before_action -> { require_permission!("requests.product_request.resolve") }, only: %i[add_to_purchase_order]
  before_action :set_product_request, only: %i[add_to_purchase_order]

  def index
    scope = Current.store.product_requests.open_requests
      .includes(:product, :product_variant, :assigned_buyer_user)
      .order(Arel.sql("CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END"), :needed_by_on, :created_at)
    scope = scope.where(request_type: params[:request_type]) if ProductRequest::REQUEST_TYPES.include?(params[:request_type])
    @pagy, @product_requests = pagy(scope, limit: pagy_limit)

    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store) ||
      Current.user.can?("inventory.cost.view", store: Current.store)
    @snapshots = @product_requests.each_with_object({}) do |request, hash|
      next if request.product_variant_id.blank?

      hash[request.id] = Purchasing::ReplenishmentSnapshot.call(store: Current.store, product_variant: request.product_variant)
    end
    @vendors = Current.organization.vendors.where(active: true).order(:code)
  end

  def add_to_purchase_order
    vendor = Current.organization.vendors.find_by(id: params[:vendor_id])
    variant = ProductVariant.find_by(id: params[:product_variant_id]) || @product_request.product_variant

    if vendor.blank?
      redirect_to buyer_review_index_path, alert: "A vendor is required to add demand to a purchase order."
      return
    end

    result = Purchasing::AddDemandToDraftPurchaseOrder.call(
      store: Current.store,
      vendor: vendor,
      product_request: @product_request,
      product_variant: variant,
      quantity: params[:quantity],
      resolve_request: ActiveModel::Type::Boolean.new.cast(params[:resolve_request].presence || true),
      resolution_note: params[:resolution_note],
      actor: Current.user
    )

    if result.success?
      redirect_to purchase_order_path(result.purchase_order), notice: "Added #{params[:quantity]} unit(s) to purchase order #{result.purchase_order.purchase_order_number}."
    else
      redirect_to buyer_review_index_path, alert: result.error
    end
  end

  private

  def set_product_request
    @product_request = Current.store.product_requests.find(params[:id])
  end
end
