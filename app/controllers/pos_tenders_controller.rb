# frozen_string_literal: true

class PosTendersController < ApplicationController
  before_action :set_transaction
  before_action :set_tender, only: %i[destroy]
  before_action -> { require_permission!(create_permission) }, only: %i[create]
  before_action -> { require_permission!(destroy_permission) }, only: %i[destroy]

  def create
    tender_type = Current.organization.tender_types.find(params[:tender_type_id])

    result = case tender_type.tender_category
    when "cash"
      if params[:refund].present?
        Pos::AddCashRefundTender.call(
          pos_transaction: @pos_transaction, tender_type: tender_type,
          amount_cents: money_param_to_cents(params[:amount_cents], label: "Refund amount"),
          actor: Current.user
        )
      else
        Pos::AddCashTender.call(
          pos_transaction: @pos_transaction, tender_type: tender_type,
          amount_tendered_cents: money_param_to_cents(params[:amount_tendered_cents], label: "Amount tendered"),
          actor: Current.user
        )
      end
    when "card"
      Pos::AddCardTender.call(
        pos_transaction: @pos_transaction, tender_type: tender_type,
        amount_cents: money_param_to_cents(params[:amount_cents], label: "Amount"),
        authorization_code: params[:authorization_code],
        terminal_reference: params[:terminal_reference].presence, actor: Current.user
      )
    when "check"
      unsupported_tender_result("check tendering is not available yet")
    else
      unsupported_tender_result("tender category '#{tender_type.tender_category}' is not supported")
    end

    if result.success?
      notice = result.respond_to?(:warnings) && result.warnings.present? ? result.warnings.join("; ") : "Tender recorded."
      redirect_to pos_transaction_path(@pos_transaction), notice: notice
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to pos_transaction_path(@pos_transaction), alert: e.message
  end

  def destroy
    result = Pos::RemoveTender.call(
      pos_tender: @tender,
      actor: Current.user,
      reason: params[:reason],
      external_void_confirmed: params[:external_void_confirmed],
      external_void_reference: params[:external_void_reference]
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Tender removed."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end

  def set_tender
    @tender = @pos_transaction.pos_tenders.find(params[:id])
  end

  def create_permission
    tender_type = params[:tender_type_id].presence && Current.organization.tender_types.find_by(id: params[:tender_type_id])
    case tender_type&.tender_category
    when "card" then "pos.tender.card_standalone"
    when "cash" then "pos.tender.cash"
    else "pos.tender.cash"
    end
  end

  def destroy_permission
    if @tender&.authorized? && @tender.tender_type.tender_category == "card"
      "pos.tender.card_void"
    else
      "pos.access"
    end
  end

  def unsupported_tender_result(message)
    Data.define(:success?, :error, :warnings).new(success?: false, error: message, warnings: [])
  end
end
