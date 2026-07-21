# frozen_string_literal: true

class ReceiptsController < ApplicationController
  before_action -> { require_permission!("inventory.receipt.view") }, only: %i[index show]
  before_action -> { require_permission!("inventory.receipt.create") }, only: %i[new create edit update]
  before_action :set_receipt, only: %i[show edit update post cancel]

  def index
    scope = Current.store.receipts.includes(:vendor).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if Receipt::STATUSES.include?(params[:status])
    @pagy, @receipts = pagy(scope, limit: pagy_limit)
    @can_view_cost = can_view_receipt_cost?
  end

  def show
    @can_view_cost = can_view_receipt_cost?
    @can_cancel = @receipt.draft? && Current.user.can?("inventory.receipt.create", store: Current.store)
    @can_post = @receipt.draft? && Current.user.can?("inventory.receipt.post", store: Current.store)
  end

  def new
    @receipt = Current.store.receipts.new
    @receipt.receipt_lines.build(delivered_quantity: 1, accepted_quantity: 1, position: 0)
    load_form_collections
  end

  def create
    @receipt = Current.store.receipts.new(header_params)
    result = Inventory::CreateReceipt.call(
      receipt: @receipt,
      lines_attributes: lines_params,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.receipt, notice: "Receipt draft created."
    else
      @receipt.errors.add(:base, result.error) if result.error.present?
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to @receipt, alert: "Only drafts can be edited." unless @receipt.draft?

    load_form_collections
  end

  def update
    result = Inventory::UpdateDraftReceipt.call(
      receipt: @receipt,
      attributes: header_params.to_h,
      lines_attributes: lines_params,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.receipt, notice: "Receipt updated."
    else
      @receipt.errors.add(:base, result.error) if result.error.present?
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def post
    result = Inventory::PostReceipt.call(receipt: @receipt, actor: Current.user, store: Current.store)
    if result.success?
      redirect_to result.receipt, notice: result.replayed ? "Receipt already posted." : "Receipt posted."
    else
      redirect_to @receipt, alert: result.error
    end
  end

  def cancel
    result = Inventory::CancelReceipt.call(
      receipt: @receipt,
      actor: Current.user,
      store: Current.store,
      cancellation_reason: params.dig(:receipt, :cancellation_reason)
    )
    if result.success?
      redirect_to result.receipt, notice: result.replayed ? "Receipt already cancelled." : "Receipt cancelled."
    else
      redirect_to @receipt, alert: result.error
    end
  end

  private

  def set_receipt
    @receipt = Current.store.receipts.find(params[:id])
  end

  def can_view_receipt_cost?
    Current.user.can?("inventory.cost.view", store: Current.store) ||
      Current.user.can?("purchasing.cost.view", store: Current.store)
  end

  def load_form_collections
    @vendors = Current.organization.vendors.where(active: true).order(:code)
    @product_variants = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id })
      .where.not(inventory_tracking_mode: "none")
      .includes(:product)
      .order("products.name", :name)
    @purchase_order_lines = PurchaseOrderLine.joins(:purchase_order)
      .where(purchase_orders: { store_id: Current.store.id, status: "ordered" })
      .includes(:product_variant, :purchase_order)
  end

  def header_params
    params.require(:receipt).permit(:vendor_id, :received_at, :received_by_user_id, :notes)
  end

  def lines_params
    raw = params.require(:receipt).permit(
      receipt_lines_attributes: [
        :id, :position, :product_variant_id, :purchase_order_line_id,
        :delivered_quantity, :accepted_quantity, :rejected_quantity, :accepted_unavailable_quantity,
        :actual_unit_cost_cents, :cost_quality, :cost_provenance, :discrepancy_reason, :notes
      ]
    )[:receipt_lines_attributes]
    return [] if raw.blank?

    values = raw.respond_to?(:values) ? raw.values : Array(raw)
    values.map(&:to_h).select { |attrs| attrs["product_variant_id"].present? }
  end
end
