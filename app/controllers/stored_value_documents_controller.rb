# frozen_string_literal: true

# Browser-printable Stored-Value Activity Slips and Credit Vouchers (Phase 11.1E–F).
# All actions are GET-only and commercially inert.
class StoredValueDocumentsController < ApplicationController
  include PosImmediatePrintContext

  layout "pos_receipt"

  before_action :disable_turbo_and_browser_cache

  def activity_slip
    require_permission!("stored_value.activity.print")
    return if performed?

    set_entry!
    return if performed?
    return reject_out_of_scope_entry! unless slip_in_scope?

    unless immediate_sv_entry_print_available?(@entry)
      return redirect_to fallback_path_for_entry,
                         alert: "Original print is only available from the immediate completion workflow. Use Reprint from account history."
    end

    render_activity_slip(reprint: false)
  rescue StoredValue::ActivitySlipFacts::Error => e
    redirect_to fallback_path_for_entry, alert: e.message
  end

  def activity_slip_reprint
    require_permission!("stored_value.activity.print")
    return if performed?

    set_entry!
    return if performed?
    return reject_out_of_scope_entry! unless slip_in_scope?

    render_activity_slip(reprint: true)
  rescue StoredValue::ActivitySlipFacts::Error => e
    redirect_to fallback_path_for_entry, alert: e.message
  end

  def credit_voucher
    require_permission!("stored_value.voucher.print")
    return if performed?

    set_account!
    return if performed?

    unless immediate_sv_account_print_available?(@account)
      return redirect_to stored_value_account_path(@account),
                         alert: "Original print is only available from the immediate completion workflow. Use Reprint from account history."
    end

    render_credit_voucher(reprint: false)
  rescue StoredValue::CreditVoucherFacts::SuspendedError => e
    redirect_to stored_value_account_path(@account), alert: e.message
  end

  def credit_voucher_reprint
    require_permission!("stored_value.voucher.print")
    return if performed?

    set_account!
    return if performed?

    render_credit_voucher(reprint: true)
  rescue StoredValue::CreditVoucherFacts::SuspendedError => e
    redirect_to stored_value_account_path(@account), alert: e.message
  end

  private

  def set_entry!
    @entry = StoredValueEntry
      .joins(:stored_value_account)
      .where(stored_value_accounts: { organization_id: Current.organization.id })
      .includes(:stored_value_account, :pos_transaction)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stored_value_accounts_path, alert: "Stored-value entry not found."
  end

  def set_account!
    @account = Current.organization.stored_value_accounts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stored_value_accounts_path, alert: "Stored-value account not found."
  end

  def slip_in_scope?
    StoredValue::ActivitySlipFacts::IN_SCOPE_ENTRY_TYPES.include?(@entry.entry_type.to_s)
  end

  def reject_out_of_scope_entry!
    redirect_to fallback_path_for_entry,
                alert: "Activity slips are only available for gift-card issue, gift-card reload, and store-credit refund entries."
  end

  def fallback_path_for_entry
    return stored_value_account_path(@entry.stored_value_account) if @entry&.stored_value_account

    stored_value_accounts_path
  end

  def render_activity_slip(reprint:)
    @facts = StoredValue::ActivitySlipFacts.call(
      entry: @entry,
      store: Current.store,
      reprint: reprint
    )
    @reprint = reprint
    render "stored_value_documents/activity_slip"
  end

  def render_credit_voucher(reprint:)
    @facts = StoredValue::CreditVoucherFacts.call(
      account: @account,
      store: Current.store,
      reprint: reprint
    )
    @reprint = reprint
    render "stored_value_documents/credit_voucher"
  end

  def disable_turbo_and_browser_cache
    response.set_header("Cache-Control", "no-store")
    response.set_header("Pragma", "no-cache")
  end
end
