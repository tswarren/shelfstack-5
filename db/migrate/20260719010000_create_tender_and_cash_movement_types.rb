# frozen_string_literal: true

class CreateTenderAndCashMovementTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :tender_types do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.string :tender_category, null: false
      t.string :shortcut, limit: 3
      t.boolean :payment_enabled, null: false, default: true
      t.boolean :refund_enabled, null: false, default: true
      t.boolean :allows_over_tender, null: false, default: false
      t.boolean :provides_change, null: false, default: false
      t.string :reference_1_requirement, null: false, default: "none"
      t.string :reference_1_label, limit: 20
      t.string :reference_1_mask
      t.string :reference_2_requirement, null: false, default: "none"
      t.string :reference_2_label, limit: 20
      t.string :reference_2_mask
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :tender_types, [ :organization_id, :code ], unique: true
    add_index :tender_types, [ :organization_id, :shortcut ], unique: true, where: "shortcut IS NOT NULL"

    create_table :cash_movement_types do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.string :direction, null: false
      t.boolean :requires_approval, null: false, default: true
      t.boolean :requires_reference, null: false, default: true
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :cash_movement_types, [ :organization_id, :code ], unique: true
  end
end
