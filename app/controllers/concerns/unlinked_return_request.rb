# frozen_string_literal: true

# Shared unlinked-return param parsing and two-step cost review for Ready and
# in-transaction controllers.
module UnlinkedReturnRequest
  extend ActiveSupport::Concern

  private

  def parse_unlinked_return_inputs!
    @unlinked_reason = Current.organization.return_reasons.find(params[:return_reason_id])
    @unlinked_variant = params[:product_variant_id].presence &&
      ProductVariant.joins(:product)
        .where(products: { organization_id: Current.organization.id })
        .find_by(id: params[:product_variant_id])
    @unlinked_department = params[:department_id].presence &&
      Current.organization.departments.find_by(id: params[:department_id])
    @unlinked_approver = params[:approver_username].presence &&
      User.find_by(username: params[:approver_username].to_s.strip.downcase)
    @unlinked_tax_category = params[:tax_category_id].presence &&
      Current.organization.tax_categories.find_by(id: params[:tax_category_id])
    @unlinked_explicit_tax = if params[:tax_basis].to_s == "external_receipt_tax"
      money_param_to_cents(params[:explicit_tax_amount_cents], label: "Explicit tax amount", required: false)
    end
    @unlinked_unit_price_cents = money_param_to_cents(params[:unit_price_cents], label: "Refund unit price")
    @unlinked_quantity = params[:quantity].presence || 1
    @unlinked_confirm_cost = ActiveModel::Type::Boolean.new.cast(params[:confirm_cost_basis])
  end

  def unlinked_return_service_kwargs
    {
      return_source: params[:return_source],
      return_reason: @unlinked_reason,
      return_disposition: params[:return_disposition],
      unit_price_cents: @unlinked_unit_price_cents,
      quantity: @unlinked_quantity,
      product_variant: @unlinked_variant,
      department: @unlinked_department,
      description: params[:description],
      tax_category: @unlinked_tax_category,
      tax_basis: params[:tax_basis],
      explicit_tax_amount_cents: @unlinked_explicit_tax,
      confirm_cost_basis: @unlinked_confirm_cost,
      reviewed_cost_unit_cents: params[:reviewed_cost_unit_cents].presence,
      reviewed_cost_source: params[:reviewed_cost_source].presence,
      approver: @unlinked_approver,
      approver_pin: params[:approver_pin]
    }
  end

  def unlinked_cost_review_needed?
    !@unlinked_confirm_cost && Pos::AddUnlinkedReturnLine.requires_cost_confirmation?(
      product_variant: @unlinked_variant,
      return_disposition: params[:return_disposition]
    )
  end

  def prepare_unlinked_cost_review!
    proposal = Pos::ProposeUnlinkedReturnCost.call(
      store: Current.store,
      product_variant: @unlinked_variant
    )
    unless proposal.available?
      return proposal.error
    end

    @cost_proposal = proposal
    @cost_review_fields = {
      return_source: params[:return_source],
      return_reason_id: @unlinked_reason.id,
      return_disposition: params[:return_disposition],
      product_variant_id: @unlinked_variant&.id,
      department_id: @unlinked_department&.id,
      description: params[:description],
      tax_category_id: @unlinked_tax_category&.id,
      tax_basis: params[:tax_basis],
      unit_price_cents: params[:unit_price_cents],
      quantity: @unlinked_quantity,
      explicit_tax_amount_cents: params[:explicit_tax_amount_cents],
      approver_username: params[:approver_username],
      approver_pin: params[:approver_pin],
      intent: params[:intent]
    }
    nil
  end
end
