# frozen_string_literal: true

module Pos
  # Canonical lock order for POS completion and post-void (sorted IDs within
  # each group). Keep CompleteTransaction and PostVoidTransaction aligned:
  #
  #   Session → Transaction → Lines/Tenders → Product Requests →
  #   Inventory (balances / units) → Stored-Value Accounts → Store receipt sequence
  module CompletionLockOrder
    module_function

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
