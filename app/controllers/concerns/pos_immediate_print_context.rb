# frozen_string_literal: true

# Server-owned immediate original-print context for Phase 11.1 receipt documents
# and Stored-Value Activity Slip / Credit Voucher documents.
# Stored in the Rails session; not a persisted domain record.
module PosImmediatePrintContext
  extend ActiveSupport::Concern

  SESSION_KEY = :pos_immediate_print_context

  DOCUMENT_CUSTOMER = "customer_receipt"
  DOCUMENT_GIFT = "gift_receipt"
  DOCUMENT_POST_VOID = "post_void_receipt"

  SLIP_ENTRY_TYPES = %w[issued reloaded refunded].freeze

  included do
    helper_method :immediate_print_available?,
                  :immediate_print_context_matches?,
                  :immediate_sv_entry_ids,
                  :immediate_sv_account_ids,
                  :immediate_sv_entry_print_available?,
                  :immediate_sv_account_print_available?
  end

  class_methods do
    def immediate_print_document_types_for(pos_transaction)
      if pos_transaction.reverses_pos_transaction_id.present?
        [ DOCUMENT_CUSTOMER, DOCUMENT_POST_VOID ]
      else
        [ DOCUMENT_CUSTOMER, DOCUMENT_GIFT ]
      end
    end
  end

  def store_immediate_print_context!(pos_transaction)
    session_id = pos_transaction.completed_pos_session_id || pos_transaction.origin_pos_session_id
    entries = pos_transaction.stored_value_entries.where(entry_type: SLIP_ENTRY_TYPES)
    entry_ids = entries.pluck(:id)
    account_ids = entries.distinct.pluck(:stored_value_account_id)

    session[SESSION_KEY] = {
      "transaction_id" => pos_transaction.id,
      "pos_session_id" => session_id,
      "allowed_document_types" => self.class.immediate_print_document_types_for(pos_transaction),
      "completed_at" => pos_transaction.completed_at&.iso8601(6),
      "stored_value_entry_ids" => entry_ids,
      "stored_value_account_ids" => account_ids
    }
  end

  def clear_immediate_print_context!
    session.delete(SESSION_KEY)
  end

  def immediate_print_context
    raw = session[SESSION_KEY]
    return nil unless raw.is_a?(Hash)

    raw
  end

  def immediate_print_context_matches?(pos_transaction, document_type:)
    ctx = immediate_print_context
    return false if ctx.blank?
    return false unless ctx["transaction_id"].to_i == pos_transaction.id

    session_id = pos_transaction.completed_pos_session_id || pos_transaction.origin_pos_session_id
    return false unless ctx["pos_session_id"].to_i == session_id.to_i

    allowed = Array(ctx["allowed_document_types"]).map(&:to_s)
    return false unless allowed.include?(document_type.to_s)

    stored_completed = ctx["completed_at"].to_s
    current_completed = pos_transaction.completed_at&.iso8601(6).to_s
    stored_completed.present? && stored_completed == current_completed
  end

  def immediate_print_available?(pos_transaction)
    ctx = immediate_print_context
    return false if ctx.blank?

    ctx["transaction_id"].to_i == pos_transaction.id
  end

  def immediate_sv_entry_ids
    Array(immediate_print_context&.dig("stored_value_entry_ids")).map(&:to_i)
  end

  def immediate_sv_account_ids
    Array(immediate_print_context&.dig("stored_value_account_ids")).map(&:to_i)
  end

  def immediate_sv_entry_print_available?(entry)
    immediate_sv_entry_ids.include?(entry.id)
  end

  def immediate_sv_account_print_available?(account)
    immediate_sv_account_ids.include?(account.id)
  end
end
