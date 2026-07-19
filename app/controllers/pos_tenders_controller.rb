# frozen_string_literal: true

class PosTendersController < ApplicationController
  before_action -> { require_permission!(create_permission) }, only: %i[create]
  before_action -> { require_permission!("pos.access") }, only: %i[destroy]
  before_action :set_transaction
  before_action :set_tender, only: %i[destroy]

  def create
    tender_type = Current.organization.tender_types.find(params[:tender_type_id])

    result = if tender_type.tender_category == "cash" && params[:refund].present?
      Pos::AddCashRefundTender.call(
        pos_transaction: @pos_transaction, tender_type: tender_type,
        amount_cents: params[:amount_cents], actor: Current.user
      )
    elsif tender_type.tender_category == "cash"
      Pos::AddCashTender.call(
        pos_transaction: @pos_transaction, tender_type: tender_type,
        amount_tendered_cents: params[:amount_tendered_cents], actor: Current.user
      )
    else
      Pos::AddCardTender.call(
        pos_transaction: @pos_transaction, tender_type: tender_type,
        amount_cents: params[:amount_cents], authorization_code: params[:authorization_code],
        terminal_reference: params[:terminal_reference].presence, actor: Current.user
      )
    end

    if result.success?
      notice = result.respond_to?(:warnings) && result.warnings.present? ? result.warnings.join("; ") : "Tender recorded."
      redirect_to pos_transaction_path(@pos_transaction), notice: notice
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def destroy
    result = Pos::RemoveTender.call(pos_tender: @tender, actor: Current.user, reason: params[:reason])
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

  # Cash and standalone-card Tenders are distinct permission keys (domain
  # authorization-permissions.md); resolve which applies from the requested
  # Tender Type's category before the underlying service runs.
  def create_permission
    tender_type = params[:tender_type_id].presence && Current.organization.tender_types.find_by(id: params[:tender_type_id])
    tender_type&.tender_category == "card" ? "pos.tender.card_standalone" : "pos.tender.cash"
  end
end
