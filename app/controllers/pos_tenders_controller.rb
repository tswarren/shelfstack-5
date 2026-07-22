# frozen_string_literal: true

class PosTendersController < ApplicationController
  before_action :set_transaction
  before_action :set_tender, only: %i[destroy resolve_reconciliation]
  before_action -> { require_permission!(create_permission) }, only: %i[create prepare_card_refund abandon_card_refund]
  before_action -> { require_permission!(destroy_permission) }, only: %i[destroy]
  before_action -> { require_permission!("pos.card_refund.reconcile") }, only: %i[resolve_reconciliation]

  def prepare_card_refund
    tender_type = Current.organization.tender_types.find(params[:tender_type_id])
    amount_cents = money_param_to_cents(params[:amount_cents], label: "Refund amount")
    result = Pos::PrepareCardRefund.call(
      pos_transaction: @pos_transaction,
      tender_type: tender_type,
      amount_cents: amount_cents,
      actor: Current.user,
      original_pos_tender: scoped_original_refund_tender(params[:original_pos_tender_id]),
      exception_approver: exception_approver_from_params,
      exception_approver_pin: params[:exception_approver_pin]
    )

    if result.ready?
      redirect_to pos_transaction_path(@pos_transaction),
                  notice: "Card refund plan ready — process the terminal refund, then record the authorization below."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  rescue ArgumentError => e
    redirect_to pos_transaction_path(@pos_transaction), alert: e.message
  end

  def abandon_card_refund
    preparation = @pos_transaction.pos_card_refund_preparations.prepared.find(params[:preparation_id])
    result = Pos::AbandonCardRefundPreparation.call(
      preparation: preparation,
      actor: Current.user,
      reason: params[:reason]
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Card refund preparation abandoned."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def create
    if params[:preparation_id].present? && params[:refund].present?
      return create_card_refund_from_preparation
    end

    tender_type = Current.organization.tender_types.find(params[:tender_type_id])

    result = case tender_type.tender_category
    when "cash"
      if params[:refund].present?
        Pos::AddCashRefundTender.call(
          pos_transaction: @pos_transaction, tender_type: tender_type,
          amount_cents: money_param_to_cents(params[:amount_cents], label: "Refund amount"),
          actor: Current.user,
          original_pos_tender: scoped_original_refund_tender(params[:original_pos_tender_id]),
          exception_approver: exception_approver_from_params,
          exception_approver_pin: params[:exception_approver_pin]
        )
      else
        Pos::AddCashTender.call(
          pos_transaction: @pos_transaction, tender_type: tender_type,
          amount_tendered_cents: money_param_to_cents(params[:amount_tendered_cents], label: "Amount tendered"),
          actor: Current.user
        )
      end
    when "card"
      if params[:refund].present?
        unsupported_tender_result("card refund requires a preparation_id; prepare the plan first")
      else
        Pos::AddCardTender.call(
          pos_transaction: @pos_transaction, tender_type: tender_type,
          amount_cents: money_param_to_cents(params[:amount_cents], label: "Amount"),
          authorization_code: params[:authorization_code],
          terminal_reference: params[:terminal_reference].presence, actor: Current.user
        )
      end
    when "stored_value"
      account = resolve_stored_value_account
      if params[:refund].present?
        original = scoped_original_refund_tender(params[:original_pos_tender_id])
        Pos::AddStoredValueRefundTender.call(
          pos_transaction: @pos_transaction, tender_type: tender_type,
          amount_cents: money_param_to_cents(params[:amount_cents], label: "Refund amount"),
          actor: Current.user,
          account: account,
          original_pos_tender: original,
          create_store_credit: params[:create_store_credit].present?,
          exception_approver: exception_approver_from_params,
          exception_approver_pin: params[:exception_approver_pin]
        )
      else
        if account.blank?
          unsupported_tender_result("stored-value account is required")
        else
          Pos::AddStoredValueTender.call(
            pos_transaction: @pos_transaction, tender_type: tender_type,
            account: account,
            amount_cents: money_param_to_cents(params[:amount_cents], label: "Amount"),
            actor: Current.user
          )
        end
      end
    when "check"
      unsupported_tender_result("check tendering is not available yet")
    else
      unsupported_tender_result("tender category '#{tender_type.tender_category}' is not supported")
    end

    redirect_after_tender_result(result)
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

  def resolve_reconciliation
    preparation = @pos_transaction.pos_card_refund_preparations.find_by!(pos_tender_id: @tender.id)
    result = Pos::ResolveCardRefundTenderReconciliation.call(
      preparation: preparation,
      actor: Current.user,
      outcome: params.require(:outcome),
      reason: params.require(:reason),
      external_void_reference: params[:external_void_reference],
      exception_approver: exception_approver_from_params,
      exception_approver_pin: params[:exception_approver_pin]
    )
    if result.success?
      redirect_to pos_transaction_path(@pos_transaction), notice: "Card refund reconciliation resolved."
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  private

  def create_card_refund_from_preparation
    preparation = Current.store.pos_transactions
      .find(@pos_transaction.id)
      .pos_card_refund_preparations
      .find(params[:preparation_id])

    result = Pos::AddCardRefundTender.call(
      preparation: preparation,
      authorization_code: params[:authorization_code],
      terminal_reference: params[:terminal_reference].presence,
      actor: Current.user
    )
    redirect_after_tender_result(result)
  rescue ActiveRecord::RecordNotFound
    redirect_to pos_transaction_path(@pos_transaction), alert: "card refund preparation not found"
  end

  def redirect_after_tender_result(result)
    if result.success?
      if result.respond_to?(:preparation) && result.preparation&.recorded_orphan?
        redirect_to pos_transaction_path(@pos_transaction),
                    alert: "External card refund recorded as an orphan for reconciliation. " \
                           "#{Array(result.warnings).join('; ')}"
      elsif result.respond_to?(:requires_reconciliation) && result.requires_reconciliation
        redirect_to pos_transaction_path(@pos_transaction),
                    alert: "Card refund recorded for reconciliation: #{Array(result.warnings).join('; ')}. " \
                           "Complete is blocked until the tender is resolved or voided."
      else
        notice = result.respond_to?(:warnings) && result.warnings.present? ? result.warnings.join("; ") : "Tender recorded."
        redirect_to pos_transaction_path(@pos_transaction), notice: notice
      end
    else
      redirect_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end

  def set_tender
    @tender = @pos_transaction.pos_tenders.find(params[:id])
  end

  def create_permission
    if params[:preparation_id].present? || action_name.in?(%w[prepare_card_refund abandon_card_refund])
      return "pos.tender.card_standalone"
    end

    tender_type = params[:tender_type_id].presence && Current.organization.tender_types.find_by(id: params[:tender_type_id])
    case tender_type&.tender_category
    when "card" then "pos.tender.card_standalone"
    when "stored_value"
      params[:refund].present? ? "stored_value.tender.refund" : "stored_value.tender.redeem"
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

  def scoped_original_refund_tender(id)
    return nil if id.blank?

    tender = Current.store.pos_tenders.find_by(id: id)
    return nil if tender.blank?

    linked_sale_ids = @pos_transaction.pos_line_items.returns.filter_map { |line|
      line.original_pos_line_item&.pos_transaction_id
    }.uniq
    return nil unless linked_sale_ids.include?(tender.pos_transaction_id)

    tender
  end

  def exception_approver_from_params
    return nil if params[:exception_approver_username].blank?

    User.find_by(username: params[:exception_approver_username].to_s.strip.downcase)
  end

  def resolve_stored_value_account
    if params[:stored_value_account_id].present?
      return Current.organization.stored_value_accounts.find_by(id: params[:stored_value_account_id])
    end

    identifier = params[:account_number].presence || params[:alternate_identifier].presence
    return nil if identifier.blank?

    StoredValue::ResolveAccount.call(
      organization: Current.organization,
      identifier: identifier
    ).account
  rescue StoredValue::ResolveAccount::Error
    nil
  end
end
