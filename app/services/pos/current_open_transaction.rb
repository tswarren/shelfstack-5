# frozen_string_literal: true

module Pos
  # Locates the open transaction controlled by a cashier in a given store.
  # Used to block sign-out and store-switching mid-sale (phase-04f).
  class CurrentOpenTransaction
    def self.for(user:, store_id:)
      return nil if user.blank? || store_id.blank?

      store = Store.find_by(id: store_id)
      return nil if store.blank?

      open_session = store.pos_sessions.open_sessions.find_by(cashier_user: user)
      return nil if open_session.blank?

      PosTransaction.open_transactions.find_by(active_pos_session: open_session)
    end
  end
end
