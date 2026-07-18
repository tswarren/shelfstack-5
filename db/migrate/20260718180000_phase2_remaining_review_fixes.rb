# frozen_string_literal: true

class Phase2RemainingReviewFixes < ActiveRecord::Migration[8.1]
  def up
    backfill_product_formats_to_other!

    if index_exists?(:product_variants, :product_id, name: "index_product_variants_on_product_id")
      remove_index :product_variants, name: "index_product_variants_on_product_id"
    end
    add_index :product_variants, :product_id, unique: true,
              name: "index_product_variants_on_product_id_unique",
              if_not_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill_product_formats_to_other!
    return unless table_exists?(:products) && table_exists?(:product_formats)

    execute <<~SQL.squish
      UPDATE products AS p
      SET product_format_id = formats.id
      FROM product_formats AS formats
      WHERE p.product_format_id IS NULL
        AND formats.organization_id = p.organization_id
        AND formats.code = 'other'
    SQL

    remaining = select_value("SELECT COUNT(*) FROM products WHERE product_format_id IS NULL")
    if remaining.to_i.positive?
      raise "#{remaining} product(s) have no product_format_id and no organization format with code 'other'. " \
            "Create that format, then re-run this migration."
    end
  end
end
