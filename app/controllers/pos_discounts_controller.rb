# frozen_string_literal: true

class PosDiscountsController < ApplicationController
  before_action -> { require_permission!("pos.access") }
  before_action -> { require_permission!("pos.discount.apply") }, only: %i[destroy]
  before_action :set_transaction
  before_action :set_discount, only: %i[destroy]

  def create
    rate_bps = discount_rate_bps_from_params
    amount_cents = if params[:amount_cents].present?
      money_param_to_cents(params[:amount_cents], label: "Amount", required: false)
    end

    result = Pos::ApplyDiscount.call(
      pos_transaction: @pos_transaction,
      scope: params[:scope],
      method: params[:method],
      pos_line_item: line_item,
      rate_bps: rate_bps,
      amount_cents: amount_cents,
      tax_treatment: params[:tax_treatment].presence || "reduces_taxable_base",
      discount_reason: discount_reason,
      reason: params[:reason],
      actor: Current.user,
      approver: approver,
      approver_pin: params[:approver_pin]
    )
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Discount applied."
      redirect_to txn_redirect_path, notice: notice
    else
      redirect_to txn_redirect_path, alert: result.error
    end
  rescue ArgumentError => e
    redirect_to txn_redirect_path, alert: e.message
  end

  def destroy
    result = Pos::RemoveDiscount.call(pos_discount: @pos_discount, actor: Current.user)
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Discount removed."
      redirect_to txn_redirect_path, notice: notice
    else
      redirect_to txn_redirect_path, alert: result.error
    end
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end

  def set_discount
    @pos_discount = @pos_transaction.pos_discounts.find(params[:id])
  end

  def txn_redirect_path
    opts = {}
    opts[:intent] = params[:intent] if params[:intent].present?
    opts[:presentation] = params[:presentation] if params[:presentation].present?
    opts[:selected_line_id] = params[:selected_line_id] if params[:selected_line_id].present?
    opts[:focus_target] = params[:focus_target] if params[:focus_target].present?
    if opts[:selected_line_id].blank? && @pos_discount&.target_pos_line_item_id.present?
      opts[:selected_line_id] = @pos_discount.target_pos_line_item_id
      opts[:focus_target] ||= "line_actions"
    end
    pos_transaction_path(@pos_transaction, opts)
  end

  def line_item
    return nil if params[:pos_line_item_id].blank?

    @pos_transaction.pos_line_items.find_by(id: params[:pos_line_item_id])
  end

  def discount_reason
    return nil if params[:discount_reason_id].blank?

    Current.organization.discount_reasons.find_by(id: params[:discount_reason_id])
  end

  def approver
    params[:approver_username].presence && User.find_by(username: params[:approver_username])
  end

  # UI posts rate_percent as percentage points. Tests/API may still post
  # integer rate_bps directly.
  def discount_rate_bps_from_params
    if params[:rate_percent].present?
      return percent_param_to_bps(params[:rate_percent], label: "Rate", required: false)
    end
    return nil if params[:rate_bps].blank?

    value = params[:rate_bps]
    if value.is_a?(Integer) || value.to_s.strip.match?(/\A-?\d+\z/)
      value.to_i
    else
      percent_param_to_bps(value, label: "Rate", required: false)
    end
  end
end
