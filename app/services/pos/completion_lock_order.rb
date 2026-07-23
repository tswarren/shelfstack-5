# frozen_string_literal: true

module Pos
  # Canonical lock order for POS completion and post-void (sorted IDs within
  # each group). Keep CompleteTransaction and PostVoidTransaction aligned:
  #
  #   Session → current Transaction → current Lines/Tenders →
  #   related original Transactions → related original Lines/Tenders →
  #   Product Requests → Inventory → Stored-Value Accounts → Store receipt sequence
  module CompletionLockOrder
    module_function

    # Locks related original sale transactions, then their lines and tenders,
    # in sorted ID order. Returns { lines:, tenders: } of locked records.
    def lock_related_originals!(lines, tenders)
      return_lines = lines.select { |line| line.direction == "return" && line.original_pos_line_item_id.present? }
      refund_tenders = tenders.select { |t| t.direction == "refunded" && t.original_pos_tender_id.present? }

      original_txn_ids = (
        return_lines.map { |line| line.original_pos_line_item.pos_transaction_id } +
        refund_tenders.map { |tender| tender.original_pos_tender.pos_transaction_id }
      ).uniq.sort
      original_txn_ids.each { |id| PosTransaction.lock.find(id) }

      original_line_ids = return_lines.map(&:original_pos_line_item_id).uniq.sort
      locked_lines = original_line_ids.index_with { |id| PosLineItem.lock.find(id) }

      original_tender_ids = (
        refund_tenders.map(&:original_pos_tender_id) +
        remaining_linked_sv_tender_ids(return_lines)
      ).uniq.sort
      locked_tenders = original_tender_ids.index_with { |id| PosTender.lock.find(id) }

      { lines: locked_lines, tenders: locked_tenders }
    end

    def remaining_linked_sv_tender_ids(return_lines)
      sale_ids = return_lines.map { |line| line.original_pos_line_item.pos_transaction_id }.uniq
      return [] if sale_ids.empty?

      PosTender
        .joins(:tender_type)
        .where(
          pos_transaction_id: sale_ids,
          direction: "received",
          status: "completed",
          tender_types: { tender_category: "stored_value" }
        )
        .pluck(:id)
    end

    def lock_inventory_for_lines!(lines)
      variant_keys = lines.filter_map { |line|
        next unless line.line_kind == "product"
        next unless line.product_variant&.inventory_tracking_mode == "quantity"

        [ line.pos_transaction.store_id, line.product_variant_id ]
      }.uniq.sort

      variant_keys.each do |store_id, variant_id|
        StockBalance.lock.find_by(store_id: store_id, product_variant_id: variant_id) ||
          Inventory::FindOrCreateStockBalance.call(
            store: Store.find(store_id), product_variant: ProductVariant.find(variant_id)
          )
      end

      unit_ids = lines.filter_map { |line|
        next unless line.line_kind == "product"
        next unless line.product_variant&.inventory_tracking_mode == "individual"

        line.inventory_unit_id
      }.compact.sort
      unit_ids.each { |id| InventoryUnit.lock.find(id) }
    end

    def lock_stored_value_accounts!(lines, tenders)
      ids = (
        lines.filter_map(&:stored_value_account_id) +
        tenders.filter_map(&:stored_value_account_id)
      ).uniq.sort
      ids.index_with { |id| StoredValueAccount.lock.find(id) }
    end
  end
end
