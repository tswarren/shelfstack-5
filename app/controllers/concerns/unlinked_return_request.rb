# frozen_string_literal: true

# Shared unlinked-return param parsing, guided wizard steps, and cost review for
# Ready and in-transaction controllers (Phase 11.2E).
module UnlinkedReturnRequest
  extend ActiveSupport::Concern

  UNLINKED_PRODUCT_STEPS = %w[identify confirm quantity reason review].freeze
  UNLINKED_OPEN_RING_STEPS = %w[identify department quantity reason review].freeze

  private

  def handle_unlinked_wizard!
    return false unless unlinked_wizard_navigation?

    @unlinked_step = next_unlinked_wizard_step
    @unlinked_open_ring = unlinked_open_ring_path? || @unlinked_step == "department"
    @return_mode = "unlinked"
    load_start_return_overlay_locals!
    render "pos_overlays/start_return", layout: false
    true
  end

  def unlinked_wizard_navigation?
    params[:wizard_continue].present? || params[:wizard_back].present? || params[:wizard_open_ring].present?
  end

  def unlinked_open_ring_path?
    ActiveModel::Type::Boolean.new.cast(params[:open_ring]) ||
      params[:wizard_open_ring].present? ||
      (params[:department_id].present? && params[:product_variant_id].blank?)
  end

  def unlinked_wizard_steps
    unlinked_open_ring_path? ? UNLINKED_OPEN_RING_STEPS : UNLINKED_PRODUCT_STEPS
  end

  def next_unlinked_wizard_step
    steps = unlinked_wizard_steps
    current = params[:unlinked_step].presence || "identify"
    current = "identify" unless steps.include?(current)

    if params[:wizard_open_ring].present?
      return "department"
    end

    index = steps.index(current) || 0
    if params[:wizard_back].present?
      return steps[[ index - 1, 0 ].max]
    end

    case current
    when "identify"
      return "confirm" if params[:product_variant_id].present?

      flash.now[:alert] = "Select a product or choose open-ring return."
      "identify"
    when "confirm"
      return "quantity" if params[:product_variant_id].present?

      flash.now[:alert] = "Confirm a product first."
      "confirm"
    when "department"
      if params[:department_id].blank?
        flash.now[:alert] = "Select a department."
        "department"
      else
        "quantity"
      end
    when "quantity"
      begin
        money_param_to_cents(params[:unit_price_cents], label: "Refund unit price")
      rescue ArgumentError => e
        flash.now[:alert] = e.message
        return "quantity"
      end
      unless params[:quantity].to_i.positive?
        flash.now[:alert] = "Quantity must be positive."
        return "quantity"
      end
      "reason"
    when "reason"
      if params[:return_reason_id].blank? || params[:return_disposition].blank?
        flash.now[:alert] = "Choose a return reason and disposition."
        "reason"
      else
        "review"
      end
    else
      steps[[ index + 1, steps.size - 1 ].min]
    end
  end

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
      intent: params[:intent],
      open_ring: params[:open_ring],
      unlinked_step: "review",
      return_mode: "unlinked"
    }
    @cost_review_needs_approval = params[:return_source].to_s == "no_receipt" &&
      Current.user.can?("pos.return.no_receipt", store: Current.store)
    nil
  end

  # Wizard and first-step posts target turbo-frame#pos_overlay. Turbo keeps loading
  # into that frame; response Turbo-Frame:_top does not retarget. Re-render the
  # overlay so the alert stays visible. Cost-confirm posts may redirect.
  def first_step_unlinked_overlay_request?
    !ActiveModel::Type::Boolean.new.cast(params[:confirm_cost_basis])
  end

  def render_unlinked_return_overlay_error(alert:)
    flash.now[:alert] = alert
    @unlinked_step = params[:unlinked_step].presence || "review"
    @unlinked_open_ring = unlinked_open_ring_path?
    @return_mode = "unlinked"
    load_start_return_overlay_locals!
    render "pos_overlays/start_return", layout: false, status: :unprocessable_entity
  end

  def load_start_return_overlay_locals!
    @return_reasons = Current.organization.return_reasons.where(active: true).order(:name)
    @tax_categories = Current.organization.tax_categories.where(active: true).order(:name)
    @departments = Department.sorted_hierarchically(
      Current.organization.departments.where(active: true, postable: true)
    )
  end

  # Cost-review success and confirm-step responses must leave #pos_overlay.
  # Setting Turbo-Frame: _top on a redirect does not retarget a form that posted
  # into pos_overlay — Turbo still tries to fill that frame. Force a full visit.
  def redirect_out_of_overlay_to(path, **options)
    flash[:notice] = options[:notice] if options[:notice].present?
    flash[:alert] = options[:alert] if options[:alert].present?

    if turbo_frame_request? && turbo_frame_request_id != "_top"
      destination = url_for(path)
      render html: view_context.javascript_tag(
        "window.Turbo.visit(#{destination.to_json}, { action: \"replace\" })"
      ), layout: false
    else
      redirect_to path, **options
    end
  end
end
