# frozen_string_literal: true

class PurchaseOrdersController < ApplicationController
  before_action -> { require_permission!("purchasing.purchase_order.view") }, only: %i[index show]
  before_action -> { require_permission!("purchasing.purchase_order.create") }, only: %i[new create]
  before_action -> { require_permission!("purchasing.purchase_order.edit") }, only: %i[edit update bulk_discount]
  before_action -> { require_permission!("purchasing.purchase_order.place") }, only: %i[place]
  before_action -> { require_permission!("purchasing.purchase_order.amend") }, only: %i[amend]
  before_action -> { require_permission!("purchasing.purchase_order.cancel") }, only: %i[cancel]
  before_action -> { require_permission!("purchasing.purchase_order.close") }, only: %i[close]
  before_action :set_purchase_order, only: %i[show edit update place amend cancel close bulk_discount]

  def index
    scope = Current.store.purchase_orders.includes(:vendor).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if PurchaseOrder::STATUSES.include?(params[:status])
    @pagy, @purchase_orders = pagy(scope, limit: pagy_limit)
    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store)
  end

  def show
    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store)
    @can_amend = @purchase_order.ordered? && Current.user.can?("purchasing.purchase_order.amend", store: Current.store)
    @can_place = @purchase_order.draft? && Current.user.can?("purchasing.purchase_order.place", store: Current.store)
    @can_cancel = %w[draft ordered].include?(@purchase_order.status) &&
      Current.user.can?("purchasing.purchase_order.cancel", store: Current.store)
    @can_close = @purchase_order.ordered? && Current.user.can?("purchasing.purchase_order.close", store: Current.store)

    if @can_amend
      @vendor_variant_options = ProductVariant.joins(:product)
        .where(products: { organization_id: Current.organization.id })
        .order("products.name", :name)
        .map { |v| [ "#{v.product.name} — #{v.name} (#{v.sku})", v.id ] }
    end
  end

  def new
    @purchase_order = Current.store.purchase_orders.new
    @purchase_order.purchase_order_lines.build(ordered_quantity: 1, cost_entry_method: "discount_from_list", position: 0)
    load_form_collections
  end

  def create
    @purchase_order = Current.store.purchase_orders.new(header_params)
    lines = lines_params
    result = Purchasing::CreatePurchaseOrder.call(
      purchase_order: @purchase_order,
      lines_attributes: lines,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.purchase_order, notice: "Purchase order draft created."
    else
      @purchase_order.errors.add(:base, result.error) if result.error.present?
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to @purchase_order, alert: "Only drafts can be edited." unless @purchase_order.draft?

    load_form_collections
  end

  def update
    result = Purchasing::UpdateDraftPurchaseOrder.call(
      purchase_order: @purchase_order,
      attributes: header_params.to_h,
      lines_attributes: lines_params,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.purchase_order, notice: "Purchase order updated."
    else
      @purchase_order.errors.add(:base, result.error) if result.error.present?
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def place
    result = Purchasing::PlacePurchaseOrder.call(purchase_order: @purchase_order, actor: Current.user, store: Current.store)
    if result.success?
      notice = result.replayed ? "Purchase order already placed." : "Purchase order placed."
      notice += " Warnings: #{result.warnings.join('; ')}" if result.warnings.present?
      redirect_to result.purchase_order, notice: notice
    else
      redirect_to @purchase_order, alert: result.error
    end
  end

  def amend
    result = Purchasing::AmendPurchaseOrder.call(
      purchase_order: @purchase_order,
      actor: Current.user,
      store: Current.store,
      cancel_lines_attributes: amend_cancel_lines_params,
      new_lines_attributes: amend_new_lines_params,
      reason: params.dig(:purchase_order, :amend_reason)
    )
    if result.success?
      redirect_to result.purchase_order, notice: "Purchase order amended."
    else
      redirect_to @purchase_order, alert: result.error
    end
  end

  def cancel
    result = Purchasing::CancelPurchaseOrder.call(
      purchase_order: @purchase_order,
      actor: Current.user,
      store: Current.store,
      cancel_reason: params.dig(:purchase_order, :cancel_reason)
    )
    if result.success?
      redirect_to result.purchase_order, notice: result.replayed ? "Purchase order already cancelled." : "Purchase order cancelled."
    else
      redirect_to @purchase_order, alert: result.error
    end
  end

  def close
    result = Purchasing::ClosePurchaseOrder.call(purchase_order: @purchase_order, actor: Current.user, store: Current.store)
    if result.success?
      redirect_to result.purchase_order, notice: result.replayed ? "Purchase order already closed." : "Purchase order closed."
    else
      redirect_to @purchase_order, alert: result.error
    end
  end

  def bulk_discount
    result = Purchasing::ApplyBulkDiscountToDraftLines.call(
      purchase_order: @purchase_order,
      line_ids: Array(params.dig(:purchase_order, :line_ids)),
      discount_bps: params.dig(:purchase_order, :discount_bps),
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.purchase_order, notice: "Discount applied to #{result.updated_line_ids.size} line(s)."
    else
      redirect_to edit_purchase_order_path(@purchase_order), alert: result.error
    end
  end

  private

  def set_purchase_order
    @purchase_order = Current.store.purchase_orders.find(params[:id])
  end

  def load_form_collections
    @vendors = Current.organization.vendors.where(active: true).order(:code)
    @product_variants = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id })
      .includes(:product)
      .order("products.name", :name)
    @product_variant_vendors = ProductVariantVendor.joins(:vendor)
      .where(vendors: { organization_id: Current.organization.id })
      .includes(:vendor, :product_variant)
    @buyers = User.joins(:store_memberships)
      .where(store_memberships: { store_id: Current.store.id })
      .distinct.order(:username)
  end

  def header_params
    params.require(:purchase_order).permit(
      :vendor_id, :buyer_user_id, :ordered_on, :expected_on, :vendor_reference, :notes
    )
  end

  def lines_params
    raw = params.require(:purchase_order).permit(
      purchase_order_lines_attributes: [
        :id, :position, :product_variant_id, :product_variant_vendor_id,
        :ordered_quantity, :cost_entry_method, :list_cost_cents, :discount_bps,
        :expected_unit_cost_cents, :returnable_snapshot, :notes
      ]
    )[:purchase_order_lines_attributes]
    return [] if raw.blank?

    values = raw.respond_to?(:values) ? raw.values : Array(raw)
    values.map(&:to_h).select { |attrs| attrs["product_variant_id"].present? }
  end

  def amend_cancel_lines_params
    raw = params.dig(:purchase_order, :cancel_lines_attributes)
    return [] if raw.blank?

    values = raw.respond_to?(:values) ? raw.values : Array(raw)
    values.map { |attrs| attrs.to_h.symbolize_keys }
      .select { |attrs| attrs[:cancelled_quantity].present? }
  end

  def amend_new_lines_params
    raw = params.dig(:purchase_order, :new_lines_attributes)
    return [] if raw.blank?

    values = raw.respond_to?(:values) ? raw.values : Array(raw)
    values.map { |attrs| attrs.to_h.symbolize_keys }
      .select { |attrs| attrs[:product_variant_id].present? }
  end
end
