# frozen_string_literal: true

class PosDiscountsController < ApplicationController
  before_action -> { require_permission!("pos.access") }
  before_action :set_transaction

  def create
    result = Pos::ApplyDiscount.call(
      pos_transaction: @pos_transaction,
      scope: params[:scope],
      method: params[:method],
      pos_line_item: line_item,
      rate_bps: params[:rate_bps],
      amount_cents: params[:amount_cents],
      tax_treatment: params[:tax_treatment].presence || "reduces_taxable_base",
      discount_reason: discount_reason,
      reason: params[:reason],
      actor: Current.user,
      approver: approver,
      approver_pin: params[:approver_pin]
    )
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Discount applied."
      redirect_to pos_transaction_path(@pos_transaction), notice: notice
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
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
end
