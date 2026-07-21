# frozen_string_literal: true

# Phase 5f: Product Request Fulfilment (OD-007). A POS-line-item is
# optionally linked to a Customer Request at line-add time so completion can
# create the append-only fulfilment fact atomically with the sale (or, for a
# linked return, a `reverse` fact undoing prior fulfilment). Allocation and
# reservation remain separate facts; fulfilment never persists a status on
# either (docs/implementation/decisions/od-007-allocation-receipt-and-fulfilment.md).
class CreatePhase5fProductRequestFulfillments < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_line_items, :product_request, foreign_key: { on_delete: :restrict }
    add_check_constraint :pos_line_items,
      "product_request_id IS NULL OR (line_kind = 'product' AND direction = 'sale')",
      name: "pos_line_items_product_request_requires_product_sale"

    # Append-only fulfilment ledger — no updated_at, mirrors
    # purchase_order_allocation_events' append-only shape.
    create_table :product_request_fulfillments do |t|
      t.references :product_request, null: false, foreign_key: { on_delete: :restrict }
      t.references :inventory_reservation, foreign_key: { on_delete: :restrict }
      t.references :pos_line_item, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false
      t.string :kind, null: false, default: "fulfill"
      t.references :linked_fulfilment, foreign_key: { to_table: :product_request_fulfillments, on_delete: :restrict }
      t.datetime :fulfilled_at, null: false
      t.references :fulfilled_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :posting_key, null: false

      t.datetime :created_at, null: false
    end

    add_index :product_request_fulfillments, :posting_key, unique: true,
      name: "index_product_request_fulfillments_on_posting_key"
    add_check_constraint :product_request_fulfillments, "quantity > 0",
      name: "prf_quantity_positive"
    add_check_constraint :product_request_fulfillments, "kind IN ('fulfill', 'reverse')",
      name: "prf_kind_check"
    add_check_constraint :product_request_fulfillments,
      "(kind = 'fulfill' AND linked_fulfilment_id IS NULL) OR (kind = 'reverse' AND linked_fulfilment_id IS NOT NULL)",
      name: "prf_reverse_requires_link"
  end
end
