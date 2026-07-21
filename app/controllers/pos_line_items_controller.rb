# frozen_string_literal: true

class PosLineItemsController < ApplicationController
  before_action -> { require_permission!("pos.access") }, only: %i[create update override_price override_tax_category]
  before_action -> { require_permission!("pos.line.remove") }, only: %i[destroy]
  before_action :set_transaction
  before_action :set_line_item, only: %i[update destroy override_price override_tax_category]

  def create
    if params[:kind] == "open_ring"
      create_open_ring_line
    else
      create_product_line
    end
  end

  def update
    result = Pos::UpdateLineQty.call(pos_line_item: @line_item, quantity: params[:quantity], actor: Current.user)
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Quantity updated."
      redirect_to pos_transaction_path(@pos_transaction), notice: notice
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def destroy
    result = Pos::RemoveLine.call(pos_line_item: @line_item, actor: Current.user, reason: params[:reason])
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Line removed."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def override_price
    result = Pos::OverridePrice.call(
      pos_line_item: @line_item,
      requested_unit_price_cents: money_param_to_cents(params[:requested_unit_price_cents], label: "New unit price"),
      actor: Current.user,
      reason: params[:reason],
      **approver_params
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Price overridden."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to pos_transaction_path(@pos_transaction), alert: e.message
  end

  def override_tax_category
    tax_category = Current.organization.tax_categories.find_by(id: params[:tax_category_id])
    if tax_category.blank?
      redirect_to pos_transaction_path(@pos_transaction), alert: "Select a tax category."
      return
    end

    result = Pos::OverrideTaxCategory.call(
      pos_line_item: @line_item,
      tax_category: tax_category,
      reason: params[:reason],
      actor: Current.user,
      **approver_params
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Tax category overridden."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def approver_params
    {
      approver: params[:approver_username].presence && User.find_by(username: params[:approver_username]),
      approver_pin: params[:approver_pin]
    }
  end

  def create_product_line
    # Explicit selection from the scan-resolution region resolves an exact
    # variant directly, bypassing the ambiguous free-text lookup.
    if params[:product_variant_id].present?
      add_selected_variant
      return
    end

    # Selecting a Customer Request alone should add that request's item —
    # staff should not have to re-scan an already-identified demand line.
    if params[:product_request_id].present? && params[:query].blank?
      add_line_from_product_request
      return
    end

    resolved = Pos::ResolveScan.call(organization: Current.organization, query: params[:query], store: Current.store)
    if resolved.variant.blank?
      if resolved.error == "ambiguous_match"
        store_scan_resolution(params[:query], params[:quantity])
        redirect_to pos_transaction_path(@pos_transaction),
          alert: scan_error_message(resolved),
          flash: { scan_outcome: "ambiguous", scan_query: params[:query].to_s }
      else
        redirect_to pos_transaction_path(@pos_transaction),
          alert: scan_error_message(resolved),
          flash: { scan_outcome: "failed", scan_query: params[:query].to_s }
      end
      return
    end

    add_line(resolved.variant, inventory_unit: resolved.inventory_unit)
  end

  def add_line_from_product_request
    product_request = Current.store.product_requests.find_by(id: params[:product_request_id])
    if product_request.blank?
      redirect_to pos_transaction_path(@pos_transaction), alert: "Select a valid customer request."
      return
    end

    variant = product_request.product_variant
    if variant.blank?
      variants = product_request.product.product_variants.where(status: "active", sellable: true).to_a
      if variants.size == 1
        variant = variants.first
      else
        redirect_to pos_transaction_path(@pos_transaction),
          alert: "This customer request has no resolved variant. Scan or search for the exact item, then keep the request selected."
        return
      end
    end

    inventory_unit = nil
    if variant.inventory_tracking_mode == "individual"
      reservation = InventoryReservation.active.find_by(
        store_id: Current.store.id,
        product_variant_id: variant.id,
        source_type: "product_request",
        source_id: product_request.id
      )
      inventory_unit = reservation&.inventory_unit
      if inventory_unit.blank?
        redirect_to pos_transaction_path(@pos_transaction),
          alert: "Scan the reserved inventory unit for this customer request, or reserve a unit on the request first."
        return
      end
    end

    add_line(variant, inventory_unit: inventory_unit)
  end

  def add_selected_variant
    variant = ProductVariant.joins(:product)
                            .where(products: { organization_id: Current.organization.id })
                            .find_by(id: params[:product_variant_id])
    if variant.blank?
      redirect_to pos_transaction_path(@pos_transaction), alert: "Select a valid product variant."
      return
    end

    add_line(variant)
  end

  def add_line(variant, inventory_unit: nil)
    product_request = if params[:product_request_id].present?
      Current.store.product_requests.find_by(id: params[:product_request_id])
    end

    result = Pos::AddLine.call(
      pos_transaction: @pos_transaction,
      product_variant: variant,
      quantity: params[:quantity].presence || 1,
      inventory_unit: inventory_unit,
      product_request: product_request,
      actor: Current.user
    )
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Line added."
      redirect_to pos_transaction_path(@pos_transaction), notice: notice, flash: { scan_outcome: "added" }
    else
      redirect_to pos_transaction_path(@pos_transaction),
        alert: result.error,
        flash: { scan_outcome: "failed", scan_query: params[:query].to_s }
    end
  end

  # Slim session payload; candidates are rebuilt on the transaction show GET.
  def store_scan_resolution(query, quantity)
    session[:pos_scan_resolution] = {
      "transaction_id" => @pos_transaction.id,
      "query" => query.to_s,
      "quantity" => (quantity.presence || 1).to_i
    }
  end

  def create_open_ring_line
    department = Current.organization.departments.find_by(id: params[:department_id])
    if department.blank?
      redirect_to pos_transaction_path(@pos_transaction), alert: "Select a department."
      return
    end

    result = Pos::AddOpenRingLine.call(
      pos_transaction: @pos_transaction,
      department: department,
      unit_price_cents: money_param_to_cents(params[:unit_price_cents], label: "Price"),
      description: params[:description],
      quantity: params[:quantity].presence || 1,
      actor: Current.user
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Open-ring line added."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to pos_transaction_path(@pos_transaction), alert: e.message
  end

  def scan_error_message(resolved)
    case resolved.error
    when "not_found" then "No product found for that scan/search."
    when "ambiguous_match" then "Multiple products matched; refine the search."
    when "no_variant" then "Product has no sellable variant."
    else "Unable to resolve scan."
    end
  end

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end

  def set_line_item
    @line_item = @pos_transaction.pos_line_items.find(params[:id])
  end
end
