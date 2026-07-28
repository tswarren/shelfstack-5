# frozen_string_literal: true

# Browser-printable POS receipt documents (Phase 11.1).
# All actions are GET-only and commercially inert.
class PosReceiptDocumentsController < ApplicationController
  include PosImmediatePrintContext

  layout "pos_receipt"

  before_action -> { require_permission!("pos.access") }
  before_action :set_transaction
  before_action :require_completed_transaction!
  before_action :disable_turbo_and_browser_cache

  def customer_receipt
    require_immediate_context!(PosImmediatePrintContext::DOCUMENT_CUSTOMER)
    return if performed?

    render_document(document: :customer, reprint: false)
  end

  def customer_receipt_reprint
    require_permission!("pos.receipt.reprint")
    return if performed?

    render_document(document: :customer, reprint: true)
  end

  def gift_receipt
    require_immediate_context!(PosImmediatePrintContext::DOCUMENT_GIFT)
    return if performed?
    return reject_gift_for_reversing! if reversing_post_void?

    render_document(document: :gift, reprint: false)
  end

  def gift_receipt_reprint
    require_permission!("pos.receipt.reprint")
    return if performed?
    return reject_gift_for_reversing! if reversing_post_void?

    render_document(document: :gift, reprint: true)
  end

  def post_void_receipt
    require_immediate_context!(PosImmediatePrintContext::DOCUMENT_POST_VOID)
    return if performed?
    return reject_non_post_void! unless reversing_post_void?

    render_document(document: :post_void, reprint: false)
  end

  def post_void_receipt_reprint
    require_permission!("pos.receipt.reprint")
    return if performed?
    return reject_non_post_void! unless reversing_post_void?

    render_document(document: :post_void, reprint: true)
  end

  private

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:id])
  end

  def require_completed_transaction!
    return if @pos_transaction.completed?

    redirect_to pos_transaction_path(@pos_transaction),
                alert: "Receipts are available only for completed transactions."
  end

  def require_immediate_context!(document_type)
    return if immediate_print_context_matches?(@pos_transaction, document_type: document_type)

    redirect_to pos_transaction_path(@pos_transaction),
                alert: "Original print is only available from the immediate completion workflow. Use Reprint from receipt history."
  end

  def reversing_post_void?
    @pos_transaction.reverses_pos_transaction_id.present?
  end

  def reject_gift_for_reversing!
    redirect_to pos_transaction_path(@pos_transaction),
                alert: "Gift receipts are not available for post-void reversing transactions."
  end

  def reject_non_post_void!
    redirect_to pos_transaction_path(@pos_transaction),
                alert: "Post-void receipts are only available for reversing post-void transactions."
  end

  def render_document(document:, reprint:)
    @facts = Pos::ReceiptDocumentFacts.call(
      pos_transaction: @pos_transaction,
      store: Current.store,
      reprint: reprint
    )
    @reprint = reprint
    template = case document
    when :customer then "pos_receipt_documents/customer_receipt"
    when :gift then "pos_receipt_documents/gift_receipt"
    when :post_void then "pos_receipt_documents/post_void_receipt"
    end
    render template
  end

  def disable_turbo_and_browser_cache
    response.set_header("Cache-Control", "no-store")
    response.set_header("Pragma", "no-cache")
  end
end
