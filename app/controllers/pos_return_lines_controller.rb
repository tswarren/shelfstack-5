# frozen_string_literal: true

class PosReturnLinesController < ApplicationController
  before_action -> { require_permission!("pos.return.create") }
  before_action :set_transaction

  def lookup
    receipt = params[:receipt_number].to_s.strip
    if receipt.blank?
      redirect_to pos_transaction_path(@pos_transaction, intent: "return"), alert: "Enter a receipt number."
      return
    end

    original = Current.store.pos_transactions.completed.find_by(receipt_number: receipt)
    if original.blank?
      session.delete(:pos_return_lookup)
      redirect_to pos_transaction_path(@pos_transaction, intent: "return"),
                  alert: "No completed transaction found for that receipt."
      return
    end

    session[:pos_return_lookup] = {
      "for_transaction_id" => @pos_transaction.id,
      "original_transaction_id" => original.id,
      "receipt_number" => original.receipt_number
    }
    redirect_to pos_transaction_path(@pos_transaction, intent: "return"),
                notice: "Receipt #{original.receipt_number} loaded for return."
  end

  def create
    if params[:mode].to_s == "unlinked"
      create_unlinked
    else
      create_linked
    end
  end

  private

  def create_linked
    original = PosLineItem.joins(:pos_transaction)
                          .where(pos_transactions: { store_id: Current.store.id, status: "completed" })
                          .find(params[:original_pos_line_item_id])
    reason = Current.organization.return_reasons.find(params[:return_reason_id])

    result = Pos::AddLinkedReturnLine.call(
      pos_transaction: @pos_transaction,
      original_pos_line_item: original,
      quantity: params[:quantity].presence || 1,
      return_reason: reason,
      return_disposition: params[:return_disposition],
      actor: Current.user
    )

    if result.success?
      redirect_to pos_transaction_path(@pos_transaction, intent: "sale", focus_target: "scan"),
                  notice: "Return line added."
    else
      redirect_to pos_transaction_path(@pos_transaction, intent: "return"), alert: result.error
    end
  end

  def create_unlinked
    reason = Current.organization.return_reasons.find(params[:return_reason_id])
    variant = params[:product_variant_id].presence &&
      ProductVariant.joins(:product)
        .where(products: { organization_id: Current.organization.id })
        .find_by(id: params[:product_variant_id])
    department = params[:department_id].presence &&
      Current.organization.departments.find_by(id: params[:department_id])
    approver = params[:approver_username].presence &&
      User.find_by(username: params[:approver_username].to_s.strip.downcase)

    result = Pos::AddUnlinkedReturnLine.call(
      pos_transaction: @pos_transaction,
      return_source: params[:return_source],
      return_reason: reason,
      return_disposition: params[:return_disposition],
      actor: Current.user,
      unit_price_cents: money_param_to_cents(params[:unit_price_cents], label: "Refund unit price"),
      quantity: params[:quantity].presence || 1,
      product_variant: variant,
      department: department,
      description: params[:description],
      approver: approver,
      approver_pin: params[:approver_pin]
    )

    if result.success?
      redirect_to pos_transaction_path(@pos_transaction, intent: "sale", focus_target: "scan"),
                  notice: "Unlinked return line added."
    else
      redirect_to pos_transaction_path(@pos_transaction, intent: "return"), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to pos_transaction_path(@pos_transaction, intent: "return"), alert: e.message
  end

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end
end
