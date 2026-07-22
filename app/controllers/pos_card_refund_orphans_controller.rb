# frozen_string_literal: true

# Store-level operational queue for unresolved recorded_orphan card refunds.
class PosCardRefundOrphansController < ApplicationController
  before_action -> { require_permission!("pos.tender.card_standalone") }
  before_action :set_preparation, only: %i[resolve]

  def index
    @preparations = PosCardRefundPreparation.unresolved_orphans
      .joins(:pos_transaction)
      .where(pos_transactions: { store_id: Current.store.id })
      .includes(:pos_transaction, :intended_original_pos_tender, :prepared_by_user, :recorded_by_user)
      .order(consumed_at: :desc)
  end

  def resolve
    correcting = if params[:correcting_pos_transaction_id].present?
      Current.store.pos_transactions.find(params[:correcting_pos_transaction_id])
    end

    result = Pos::ResolveCardRefundOrphan.call(
      preparation: @preparation,
      actor: Current.user,
      resolution_kind: params.require(:resolution_kind),
      reason: params.require(:reason),
      external_void_reference: params[:external_void_reference],
      correcting_pos_transaction: correcting
    )
    if result.success?
      redirect_to pos_card_refund_orphans_path, notice: "Orphan card refund resolved."
    else
      redirect_to pos_card_refund_orphans_path, alert: result.error
    end
  end

  private

  def set_preparation
    @preparation = PosCardRefundPreparation.unresolved_orphans
      .joins(:pos_transaction)
      .where(pos_transactions: { store_id: Current.store.id })
      .find(params[:id])
  end
end
