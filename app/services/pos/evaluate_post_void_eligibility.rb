# frozen_string_literal: true

module Pos
  # Unlocked preflight for post-void UI. PostVoidTransaction re-runs the same
  # checks after acquiring locks.
  class EvaluatePostVoidEligibility < ApplicationService
    Result = Data.define(:eligible?, :blockers, :warnings)

    def initialize(original_transaction:, store: nil)
      @original = original_transaction
      @store = store || original_transaction.store
    end

    def call
      blockers = []
      blockers << "transaction is not completed" unless @original.completed?
      blockers << "transaction belongs to a different store" if @original.store_id != @store.id
      blockers << "transaction is itself a post-void" if @original.reverses_pos_transaction_id.present?
      blockers << "transaction has already been post-voided" if PosTransaction.exists?(reverses_pos_transaction_id: @original.id)

      lines = @original.pos_line_items.where(status: "completed").to_a
      tenders = @original.pos_tenders.where(status: "completed").to_a

      # Post-voiding returns needs append-only fulfilment restoration when the
      # return previously reversed a Product Request fulfilment. Retain the block
      # for all return-containing originals until that path lands.
      if lines.any? { |line| line.direction == "return" }
        blockers << "return-containing transactions are not post-voidable until fulfilment restoration lands"
      end

      lines.each do |line|
        if line.direction == "sale" && line.linked_return_lines.where(status: "completed").exists?
          blockers << "sale line #{line.id} has already been returned"
        end
        blockers.concat(unit_blockers(line))
        blockers.concat(deficit_blockers(line))
        blockers.concat(stored_value_line_blockers(line))
      end

      tenders.each do |tender|
        if tender.refund_tenders.where(status: "completed").exists?
          blockers << "tender #{tender.id} has already been refunded"
        end
        blockers.concat(stored_value_tender_blockers(tender))
      end

      Result.new(eligible?: blockers.empty?, blockers: blockers.uniq, warnings: [])
    end

    private

    def stored_value_line_blockers(line)
      return [] unless line.line_kind == "stored_value"
      return [] if line.stored_value_account_id.blank?

      entry = StoredValueEntry.find_by(pos_line_item_id: line.id)
      return [ "stored-value line #{line.id} has no ledger entry to reverse" ] if entry.blank?
      return [ "stored-value entry for line #{line.id} was already reversed" ] if StoredValueEntry.exists?(reverses_entry_id: entry.id)

      # Later redemption blocks reversing earlier positive POS credit.
      if entry.amount_cents.positive? && later_redemption_exists?(entry)
        return [ "stored-value line #{line.id} credit was later redeemed; post-void blocked" ]
      end

      []
    end

    def stored_value_tender_blockers(tender)
      return [] if tender.stored_value_account_id.blank?

      entry = StoredValueEntry.find_by(pos_tender_id: tender.id)
      return [ "stored-value tender #{tender.id} has no ledger entry to reverse" ] if entry.blank?
      return [ "stored-value entry for tender #{tender.id} was already reversed" ] if StoredValueEntry.exists?(reverses_entry_id: entry.id)

      if entry.amount_cents.positive? && later_redemption_exists?(entry)
        return [ "stored-value tender #{tender.id} credit was later redeemed; post-void blocked" ]
      end

      []
    end

    def later_redemption_exists?(entry)
      StoredValueEntry
        .where(stored_value_account_id: entry.stored_value_account_id, entry_type: "redeemed")
        .where("created_at > ? OR (created_at = ? AND id > ?)", entry.created_at, entry.created_at, entry.id)
        .exists?
    end

    def unit_blockers(line)
      return [] unless line.line_kind == "product"
      return [] unless line.product_variant&.inventory_tracking_mode == "individual"
      return [ "line #{line.id} is missing its inventory unit" ] if line.inventory_unit_id.blank?

      unit = line.inventory_unit
      return [ "unit for line #{line.id} is not in a reversible sold state" ] unless unit.status == "sold"
      return [ "unit for line #{line.id} was not sold on that line" ] unless unit.sold_pos_line_item_id == line.id

      []
    end

    def deficit_blockers(line)
      return [] unless line.line_kind == "product"
      return [] unless line.product_variant&.inventory_tracking_mode == "quantity"

      sale_entry = InventoryLedgerEntry.find_by(posting_key: Inventory::ConvertReservation.posting_key(line))
      return [] if sale_entry.blank?

      prior_deficit = [ -(sale_entry.resulting_on_hand - sale_entry.quantity_delta), 0 ].max
      resulting_deficit = [ -sale_entry.resulting_on_hand, 0 ].max
      return [] unless resulting_deficit > prior_deficit

      later = InventoryLedgerEntry
        .where(store_id: sale_entry.store_id, product_variant_id: sale_entry.product_variant_id)
        .where("posted_at > ? OR (posted_at = ? AND id > ?)", sale_entry.posted_at, sale_entry.posted_at, sale_entry.id)
        .order(:posted_at, :id)

      later.each do |entry|
        prev = entry.resulting_on_hand - entry.quantity_delta
        prev_def = [ -prev, 0 ].max
        next_def = [ -entry.resulting_on_hand, 0 ].max
        if next_def < prev_def
          return [ "sale line #{line.id} increased deficit that was later reduced; post-void blocked (OD-014 interim)" ]
        end
      end

      []
    end
  end
end
