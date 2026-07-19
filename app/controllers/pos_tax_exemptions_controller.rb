# frozen_string_literal: true

class PosTaxExemptionsController < ApplicationController
  before_action -> { require_permission!("pos.access") }
  before_action :set_transaction

  def create
    result = Pos::ApplyTaxExemption.call(
      pos_transaction: @pos_transaction,
      exemption_type: params[:exemption_type],
      notes: params[:notes],
      actor: Current.user,
      approver: approver,
      approver_pin: params[:approver_pin]
    )
    if result.success?
      notice = result.warnings.present? ? result.warnings.join("; ") : "Whole-transaction tax exemption applied."
      redirect_to pos_transaction_path(@pos_transaction), notice: notice
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end

  def approver
    params[:approver_username].presence && User.find_by(username: params[:approver_username])
  end
end
