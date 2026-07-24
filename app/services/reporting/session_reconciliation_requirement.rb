# frozen_string_literal: true

module Reporting
  # Single rule for whether a closed session must be reconciled before day recon.
  module SessionReconciliationRequirement
    module_function

    def required?(session)
      return false unless session.closed?
      return true if session.cash_enabled?

      session.store.card_reconciliation_grain == "session" && completed_card_tenders?(session)
    end

    def completed_card_tenders?(session)
      PosTender
        .joins(:tender_type, :pos_transaction)
        .where(pos_transactions: { completed_pos_session_id: session.id, status: "completed" })
        .where(status: "completed", removed_at: nil)
        .where(tender_types: { tender_category: "card" })
        .exists?
    end
  end
end
