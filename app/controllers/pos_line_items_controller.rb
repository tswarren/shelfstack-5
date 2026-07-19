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
      requested_unit_price_cents: params[:requested_unit_price_cents],
      actor: Current.user,
      reason: params[:reason],
      **approver_params
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Price overridden."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
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
    resolved = Pos::ResolveScan.call(organization: Current.organization, query: params[:query], store: Current.store)
    if resolved.variant.blank?
      redirect_to pos_transaction_path(@pos_transaction), alert: scan_error_message(resolved)
      return
    end

    result = Pos::AddLine.call(
      pos_transaction: @pos_transaction,
      product_variant: resolved.variant,
      quantity: params[:quantity].presence || 1,
      actor: Current.user
    )
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Line added."
      redirect_to pos_transaction_path(@pos_transaction), notice: notice
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
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
      unit_price_cents: params[:unit_price_cents],
      description: params[:description],
      quantity: params[:quantity].presence || 1,
      actor: Current.user
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Open-ring line added."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
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
