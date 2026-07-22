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
          actor: Current.user,
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
        Pos::AddCardRefundTender.call(
          pos_transaction: @pos_transaction, tender_type: tender_type,
          amount_cents: money_param_to_cents(params[:amount_cents], label: "Refund amount"),
          authorization_code: params[:authorization_code],
          terminal_reference: params[:terminal_reference].presence,
          actor: Current.user,
          exception_approver: exception_approver_from_params,
          exception_approver_pin: params[:exception_approver_pin]
        )
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

  # Original SV tenders must belong to this store and to a sale linked by a
  # return line on the current transaction.
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
