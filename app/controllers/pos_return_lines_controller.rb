# frozen_string_literal: true

class PosReturnLinesController < ApplicationController
  include UnlinkedReturnRequest

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
      redirect_to pos_transaction_path(@pos_transaction),
                  alert: "No completed transaction found for that receipt."
      return
    end

    session[:pos_return_lookup] = {
      "for_transaction_id" => @pos_transaction.id,
      "original_transaction_id" => original.id,
      "receipt_number" => original.receipt_number
    }
    redirect_to pos_transaction_path(@pos_transaction),
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
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def create_unlinked
    parse_unlinked_return_inputs!

    if unlinked_cost_review_needed?
      error = prepare_unlinked_cost_review!
      if error
        return redirect_to pos_transaction_path(@pos_transaction), alert: error
      end

      @cost_review_form_url = pos_transaction_pos_return_lines_path(@pos_transaction)
      @cost_review_form_id = "txn_unlinked_return_cost_confirm_form"
      @cost_review_submit_label = "Confirm and add return"
      return render "pos_overlays/unlinked_return_cost_review", layout: "pos"
    end

    result = Pos::AddUnlinkedReturnLine.call(
      pos_transaction: @pos_transaction,
      actor: Current.user,
      **unlinked_return_service_kwargs
    )

    if result.success?
      redirect_to pos_transaction_path(@pos_transaction, intent: "sale", focus_target: "scan"),
                  notice: "Unlinked return line added."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to pos_transaction_path(@pos_transaction), alert: e.message
  end

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end
end
