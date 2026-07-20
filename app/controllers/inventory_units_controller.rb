# frozen_string_literal: true

class InventoryUnitsController < ApplicationController
  before_action -> { require_permission!("inventory.unit.manage") }
  before_action :set_inventory_unit, only: %i[show]

  def index
    scope = Current.store.inventory_units.includes(product_variant: :product).order(created_at: :desc)
    @pagy, @inventory_units = pagy(scope, limit: pagy_limit)
  end

  def show; end

  def new
    @inventory_unit = Current.store.inventory_units.new(product_variant_id: params[:product_variant_id])
    load_form_collections
  end

  def create
    attrs = unit_params
    variant = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id })
      .find_by(id: attrs[:product_variant_id])

    if variant.blank?
      @inventory_unit = Current.store.inventory_units.new(attrs)
      @inventory_unit.errors.add(:product_variant, "must be an individually tracked variant")
      load_form_collections
      render :new, status: :unprocessable_entity
      return
    end

    if human_readable_params_invalid?
      @inventory_unit = Current.store.inventory_units.new(attrs)
      copy_human_readable_param_errors!(@inventory_unit)
      load_form_collections
      render :new, status: :unprocessable_entity
      return
    end

    result = Inventory::CreateInventoryUnit.call(
      store: Current.store,
      product_variant: variant,
      actor: Current.user,
      acquisition_cost_cents: attrs[:acquisition_cost_cents].presence,
      product_condition: Current.organization.product_conditions.find_by(id: attrs[:product_condition_id]),
      unit_price_cents: attrs[:unit_price_cents].presence,
      acquisition_source_type: attrs[:acquisition_source_type].presence,
      description: attrs[:description].presence,
      internal_notes: attrs[:internal_notes].presence
    )

    if result.success?
      redirect_to result.inventory_unit, notice: "Inventory unit #{result.inventory_unit.unit_identifier} created."
    else
      @inventory_unit = Current.store.inventory_units.new(attrs)
      load_form_collections
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_inventory_unit
    @inventory_unit = Current.store.inventory_units.find(params[:id])
  end

  def load_form_collections
    @variants = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id }, inventory_tracking_mode: "individual")
      .order(:sku)
    @product_conditions = Current.organization.product_conditions.where(active: true).order(:position)
  end

  def unit_params
    attrs = params.require(:inventory_unit).permit(
      :product_variant_id, :acquisition_cost_cents, :unit_price_cents,
      :product_condition_id, :acquisition_source_type, :description, :internal_notes,
      :acquisition_cost, :unit_price
    )
    # Costs are entered as decimal dollars in the UI and converted to integer
    # cents before the service contract runs. Direct `_cents` input (tests) still
    # works when the decimal field is absent.
    if params[:inventory_unit].key?(:acquisition_cost)
      write_parsed_attr!(
        attrs, :acquisition_cost_cents, parse_money_param(params[:inventory_unit][:acquisition_cost]),
        presentation_attr: :acquisition_cost
      )
    end
    if params[:inventory_unit].key?(:unit_price)
      write_parsed_attr!(
        attrs, :unit_price_cents, parse_money_param(params[:inventory_unit][:unit_price]),
        presentation_attr: :unit_price
      )
    end
    attrs.except(:acquisition_cost, :unit_price)
  end
end
