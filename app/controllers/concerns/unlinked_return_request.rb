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
    # Never replay approver_pin into HTML. Collect PIN only on the confirm form.
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
      intent: params[:intent]
    }
    @cost_review_needs_approval = params[:return_source].to_s == "no_receipt" &&
      Current.user.can?("pos.return.no_receipt", store: Current.store)
    nil
  end

  # First-step posts target turbo-frame#pos_overlay. Turbo keeps loading into that
  # frame; response Turbo-Frame:_top does not retarget. Re-render the overlay so
  # the alert stays visible. Confirm-step posts use turbo_frame:_top and may redirect.
  def first_step_unlinked_overlay_request?
    !ActiveModel::Type::Boolean.new.cast(params[:confirm_cost_basis])
  end

  def render_unlinked_return_overlay_error(alert:)
    flash.now[:alert] = alert
    load_start_return_overlay_locals!
    render "pos_overlays/start_return", layout: false, status: :unprocessable_entity
  end

  def load_start_return_overlay_locals!
    @return_reasons = Current.organization.return_reasons.where(active: true).order(:name)
    @tax_categories = Current.organization.tax_categories.where(active: true).order(:name)
  end

  # Cost-review success and confirm-step responses escape so the POS shell reloads.
  def redirect_out_of_overlay_to(path, **options)
    response.set_header("Turbo-Frame", "_top")
    redirect_to path, **options
  end
end
