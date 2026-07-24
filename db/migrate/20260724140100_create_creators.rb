# frozen_string_literal: true

# Gate 8b Slice 1 (OD-P8-02): organization-owned Creator master. `normalized_name`
# is indexed but not unique -- different Creators may share a normalized name;
# perfect identity reconciliation is not a Phase 8 requirement.
class CreateCreators < ActiveRecord::Migration[8.1]
  def change
    create_table :creators do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :display_name, null: false
      t.string :normalized_name, null: false
      t.string :sort_name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :creators, [ :organization_id, :normalized_name ]
    add_index :creators, [ :organization_id, :active, :sort_name ]
  end
end
