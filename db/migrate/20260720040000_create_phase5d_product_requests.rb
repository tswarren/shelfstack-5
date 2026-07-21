# frozen_string_literal: true

class CreatePhase5dProductRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :product_requests do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.string :request_type, null: false
      t.string :status, null: false, default: "open"
      t.references :product, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_variant, foreign_key: { on_delete: :restrict }
      t.integer :requested_quantity, null: false
      t.string :priority, null: false, default: "normal"
      t.date :needed_by_on
      t.string :customer_reference
      t.references :requested_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :assigned_buyer_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :resolution
      t.integer :resolved_quantity
      t.datetime :resolved_at
      t.references :resolved_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :resolution_note
      t.text :notes
      t.references :supersedes_product_request, foreign_key: { to_table: :product_requests, on_delete: :restrict }

      t.timestamps
    end

    add_index :product_requests, [ :store_id, :status ]
    add_index :product_requests, [ :store_id, :request_type ]
    add_index :product_requests, [ :store_id, :request_type, :status ], name: "index_product_requests_on_store_type_status"

    add_check_constraint :product_requests,
      "request_type IN ('customer_request', 'staff_suggestion', 'stock_replenishment', 'frontlist_selection')",
      name: "product_requests_request_type_check"
    add_check_constraint :product_requests,
      "status IN ('open', 'fulfilled', 'declined', 'cancelled', 'closed')",
      name: "product_requests_status_check"
    add_check_constraint :product_requests,
      "priority IN ('normal', 'high', 'urgent')",
      name: "product_requests_priority_check"
    add_check_constraint :product_requests,
      "resolution IS NULL OR resolution IN ('ordered', 'declined', 'deferred', 'duplicate', 'superseded', 'no_longer_needed')",
      name: "product_requests_resolution_check"
    add_check_constraint :product_requests, "requested_quantity > 0",
      name: "product_requests_requested_quantity_positive"
    add_check_constraint :product_requests, "resolved_quantity IS NULL OR resolved_quantity >= 0",
      name: "product_requests_resolved_quantity_nonneg"
    add_check_constraint :product_requests, "resolved_quantity IS NULL OR resolved_quantity <= requested_quantity",
      name: "product_requests_resolved_quantity_within_requested"
    add_check_constraint :product_requests, "supersedes_product_request_id IS NULL OR supersedes_product_request_id <> id",
      name: "product_requests_supersedes_not_self"
  end
end
