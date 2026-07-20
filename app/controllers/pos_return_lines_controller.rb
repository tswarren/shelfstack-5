# frozen_string_literal: true

class PosReturnLinesController < ApplicationController
  before_action -> { require_permission!("pos.return.create") }
  before_action :set_transaction

  def lookup
    receipt = params[:receipt_number].to_s.strip
    if receipt.blank?
      redirect_to pos_transaction_path(@pos_transaction), alert: "Enter a receipt number."
      return
    end

    original = Current.store.pos_transactions.completed.find_by(receipt_number: receipt)
    if original.blank?
      session.delete(:pos_return_lookup)
      redirect_to pos_transaction_path(@pos_transaction), alert: "No completed transaction found for that receipt."
      return
    end

    session[:pos_return_lookup] = {
      "for_transaction_id" => @pos_transaction.id,
      "original_transaction_id" => original.id,
      "receipt_number" => original.receipt_number
    }
    redirect_to pos_transaction_path(@pos_transaction), notice: "Receipt #{original.receipt_number} loaded for return."
  end

  def create
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
      redirect_to pos_transaction_path(@pos_transaction), notice: "Return line added."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end
end
