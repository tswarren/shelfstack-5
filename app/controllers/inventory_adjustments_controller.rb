# frozen_string_literal: true

class InventoryAdjustmentsController < ApplicationController
  before_action -> { require_permission!("inventory.stock.view") }, only: %i[index show]
  before_action -> { require_permission!("inventory.adjustment.create") }, only: %i[new create edit update]
  before_action :set_adjustment, only: %i[show edit update post cancel]

  def index
    scope = Current.store.inventory_adjustments
      .includes(:inventory_adjustment_reason)
      .order(created_at: :desc)
    @pagy, @inventory_adjustments = pagy(scope, limit: pagy_limit)
  end

  def show
    @can_view_cost = can_view_adjustment_cost?
  end

  def new
    @inventory_adjustment = Current.store.inventory_adjustments.new(
      kind: params[:kind].presence || "opening_inventory",
      status: "draft"
    )
    @inventory_adjustment.inventory_adjustment_lines.build(quantity_delta: 1, position: 0)
    load_form_collections
  end

  def create
    @inventory_adjustment = Current.store.inventory_adjustments.new(adjustment_header_params)
    lines = lines_params
    if @line_param_errors.present?
      load_form_collections
      flash.now[:alert] = @line_param_errors.join("; ")
      render :new, status: :unprocessable_entity
      return
    end

    result = Inventory::CreateAdjustment.call(
      adjustment: @inventory_adjustment,
      lines_attributes: lines,
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
    lines = lines_params
    if @line_param_errors.present?
      load_form_collections
      flash.now[:alert] = @line_param_errors.join("; ")
      render :edit, status: :unprocessable_entity
      return
    end

    result = Inventory::UpdateAdjustment.call(
      adjustment: @inventory_adjustment,
      attributes: adjustment_header_params.to_h,
      lines_attributes: lines,
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

  def can_view_adjustment_cost?
    return true if Current.user.can?("inventory.cost.view", store: Current.store)
    return false unless @inventory_adjustment.draft?

    @inventory_adjustment.created_by_user_id == Current.user.id ||
      Current.user.can?("inventory.adjustment.create", store: Current.store)
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
        :corrected_inventory_value_cents,
        :input_unit_cost, :corrected_inventory_value
      ]
    )[:inventory_adjustment_lines_attributes]
    return [] if raw.blank?

    values = raw.respond_to?(:values) ? raw.values : Array(raw)
    values.map { |attrs| normalize_line_attrs(attrs.to_h.symbolize_keys) }
  end

  # Cost/value fields are entered as decimal dollars in the UI and converted to
  # integer cents before the service contract runs. Direct `_cents` input (tests)
  # keeps working when the decimal field is absent.
  def normalize_line_attrs(attrs)
    if attrs.key?(:input_unit_cost)
      value = attrs.delete(:input_unit_cost)
      parsed = parse_money_param(value)
      case parsed.status
      when :ok then attrs[:input_unit_cost_cents] = parsed.value
      when :blank then attrs[:input_unit_cost_cents] = nil
      when :invalid
        (@line_param_errors ||= []) << "Unit cost #{parsed.error || "is not a valid amount"}"
      end
    end
    if attrs.key?(:corrected_inventory_value)
      value = attrs.delete(:corrected_inventory_value)
      parsed = parse_money_param(value)
      case parsed.status
      when :ok then attrs[:corrected_inventory_value_cents] = parsed.value
      when :blank then attrs[:corrected_inventory_value_cents] = nil
      when :invalid
        (@line_param_errors ||= []) << "Corrected inventory value #{parsed.error || "is not a valid amount"}"
      end
    end

    %i[
      input_unit_cost_cents input_cost_method input_cost_quality
      corrected_inventory_value_cents
    ].each do |key|
      attrs[key] = nil if attrs.key?(key) && attrs[key].blank?
    end
    attrs
  end
end
