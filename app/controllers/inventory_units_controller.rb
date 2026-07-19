# frozen_string_literal: true

class InventoryUnitsController < ApplicationController
  before_action -> { require_permission!("inventory.unit.manage") }
  before_action :set_inventory_unit, only: %i[show]

  def index
    @inventory_units = Current.store.inventory_units.order(created_at: :desc)
  end

  def show; end

  def new
    @inventory_unit = Current.store.inventory_units.new(product_variant_id: params[:product_variant_id])
    load_form_collections
  end

  def create
    variant = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id })
      .find_by(id: unit_params[:product_variant_id])

    if variant.blank?
      load_form_collections
      flash.now[:alert] = "Select an individually tracked variant."
      render :new, status: :unprocessable_entity
      return
    end

    result = Inventory::CreateInventoryUnit.call(
      store: Current.store,
      product_variant: variant,
      actor: Current.user,
      acquisition_cost_cents: unit_params[:acquisition_cost_cents].presence,
      product_condition: Current.organization.product_conditions.find_by(id: unit_params[:product_condition_id]),
      unit_price_cents: unit_params[:unit_price_cents].presence,
      acquisition_source: unit_params[:acquisition_source].presence,
      notes: unit_params[:notes].presence
    )

    if result.success?
      redirect_to result.inventory_unit, notice: "Inventory unit #{result.inventory_unit.unit_identifier} created."
    else
      @inventory_unit = Current.store.inventory_units.new(unit_params)
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
    params.require(:inventory_unit).permit(
      :product_variant_id, :acquisition_cost_cents, :unit_price_cents,
      :product_condition_id, :acquisition_source, :notes
    )
  end
end
