# frozen_string_literal: true

class InventoryAdjustmentsController < ApplicationController
  before_action -> { require_permission!("inventory.stock.view") }, only: %i[index show]
  before_action -> { require_permission!("inventory.adjustment.create") }, only: %i[new create edit update]
  before_action :set_adjustment, only: %i[show edit update post cancel]

  def index
    @inventory_adjustments = Current.store.inventory_adjustments.order(created_at: :desc)
  end

  def show
    @can_view_cost = Current.user.can?("inventory.cost.view", store: Current.store)
  end

  def new
    @inventory_adjustment = Current.store.inventory_adjustments.new(
      kind: params[:kind].presence || "opening_inventory",
      status: "draft"
    )
    @inventory_adjustment.inventory_adjustment_lines.build(quantity_delta: 0, position: 0)
    load_form_collections
  end

  def create
    @inventory_adjustment = Current.store.inventory_adjustments.new(adjustment_header_params)
    result = Inventory::CreateAdjustment.call(
      adjustment: @inventory_adjustment,
      lines_attributes: lines_params,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.adjustment, notice: "Adjustment draft created."
    else
      load_form_collections
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to @inventory_adjustment, alert: "Only drafts can be edited." unless @inventory_adjustment.draft?

    load_form_collections
  end

  def update
    result = Inventory::UpdateAdjustment.call(
      adjustment: @inventory_adjustment,
      attributes: adjustment_header_params.to_h,
      lines_attributes: lines_params,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.adjustment, notice: "Adjustment updated."
    else
      load_form_collections
      flash.now[:alert] = result.error
      render :edit, status: :unprocessable_entity
    end
  end

  def post
    result = Inventory::PostAdjustment.call(
      adjustment: @inventory_adjustment,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.adjustment, notice: result.replayed ? "Adjustment already posted." : "Adjustment posted."
    else
      redirect_to @inventory_adjustment, alert: result.error
    end
  end

  def cancel
    result = Inventory::CancelAdjustment.call(
      adjustment: @inventory_adjustment,
      actor: Current.user,
      store: Current.store,
      cancel_note: params.require(:inventory_adjustment).permit(:cancel_note)[:cancel_note]
    )
    if result.success?
      redirect_to result.adjustment, notice: "Adjustment cancelled."
    else
      redirect_to @inventory_adjustment, alert: result.error
    end
  end

  private

  def set_adjustment
    @inventory_adjustment = Current.store.inventory_adjustments.find(params[:id])
  end

  def load_form_collections
    @reasons = Current.organization.inventory_adjustment_reasons.active.ordered
    @variants = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id }, inventory_tracking_mode: "quantity")
      .order(:sku)
  end

  def adjustment_header_params
    params.require(:inventory_adjustment).permit(:kind, :inventory_adjustment_reason_id, :note)
  end

  def lines_params
    raw = params.require(:inventory_adjustment).permit(
      inventory_adjustment_lines_attributes: [
        :id, :product_variant_id, :position, :quantity_delta,
        :input_unit_cost_cents, :input_cost_method, :input_cost_quality,
        :corrected_inventory_value_cents
      ]
    )[:inventory_adjustment_lines_attributes]
    return [] if raw.blank?

    values = raw.respond_to?(:values) ? raw.values : Array(raw)
    values.map { |attrs| normalize_line_attrs(attrs.to_h.symbolize_keys) }
  end

  def normalize_line_attrs(attrs)
    %i[
      input_unit_cost_cents input_cost_method input_cost_quality
      corrected_inventory_value_cents
    ].each do |key|
      attrs[key] = nil if attrs.key?(key) && attrs[key].blank?
    end
    attrs
  end
end

