# frozen_string_literal: true

# Store-level operational queue for unresolved recorded_orphan card refunds,
# plus late-authorization recovery for abandoned or closed preparations.
class PosCardRefundOrphansController < ApplicationController
  before_action -> { require_permission!("pos.card_refund.reconcile") }
  before_action :set_preparation, only: %i[resolve]

  def index
    @preparations = PosCardRefundPreparation.unresolved_orphans
      .joins(:pos_transaction)
      .where(pos_transactions: { store_id: Current.store.id })
      .includes(:pos_transaction, :intended_original_pos_tender, :prepared_by_user, :recorded_by_user)
      .order(consumed_at: :desc)
    @post_void_card_preparations = PosPostVoidCardPreparation.recorded_unresolved
      .where(store_id: Current.store.id)
      .includes(:original_pos_transaction, :original_pos_tender)
      .order(authorized_at: :desc)
  end

  def record_authorization
    preparation = store_scoped_preparations.find(params.require(:preparation_id))
    result = Pos::AddCardRefundTender.call(
      preparation: preparation,
      authorization_code: params.require(:authorization_code),
      terminal_reference: params[:terminal_reference],
      actor: Current.user
    )
    if result.success?
      notice =
        if result.preparation.recorded_orphan?
          "Late authorization recorded as an unresolved orphan."
        else
          "Authorization recorded on the open return."
        end
      redirect_to pos_card_refund_orphans_path, notice: notice
    else
      redirect_to pos_card_refund_orphans_path, alert: result.error
    end
  end

  def resolve
    result = Pos::ResolveCardRefundOrphan.call(
      preparation: @preparation,
      actor: Current.user,
      resolution_kind: params.require(:resolution_kind),
      reason: params.require(:reason),
      external_void_reference: params[:external_void_reference],
      exception_approver: exception_approver_from_params,
      exception_approver_pin: params[:exception_approver_pin]
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

  def store_scoped_preparations
    PosCardRefundPreparation
      .joins(:pos_transaction)
      .where(pos_transactions: { store_id: Current.store.id })
  end

  def exception_approver_from_params
    return nil if params[:exception_approver_username].blank?

    User.find_by(username: params[:exception_approver_username].to_s.strip.downcase)
  end
end
