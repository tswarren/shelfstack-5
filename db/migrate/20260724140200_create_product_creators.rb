# frozen_string_literal: true

# Gate 8b Slice 1 (OD-P8-02): ordered Product-Creator join. Positions are
# service-authoritative (Catalog::ReplaceProductCreators derives contiguous
# zero-based positions from submitted order; the DB check only guards against
# a negative value). Same creator + role on one product is soft-validated at
# the model layer only -- no unique DB constraint on (product_id, creator_id, role).
class CreateProductCreators < ActiveRecord::Migration[8.1]
  def change
    create_table :product_creators do |t|
      t.references :product, null: false, foreign_key: { on_delete: :restrict }
      t.references :creator, null: false, foreign_key: { on_delete: :restrict }
      t.string :role, null: false
      t.integer :position, null: false
      t.string :credited_as
      t.timestamps
    end

    add_check_constraint :product_creators,
                         "role IN ('author', 'editor', 'illustrator', 'translator', 'narrator', 'photographer', 'contributor')",
                         name: "product_creators_role_allowed"
    add_check_constraint :product_creators, "position >= 0", name: "product_creators_position_non_negative"

    add_index :product_creators, [ :product_id, :position, :id ], name: "index_product_creators_on_product_position_id"
  end
end
