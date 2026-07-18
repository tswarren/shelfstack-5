# frozen_string_literal: true

class HardenPhase2ReviewFixes < ActiveRecord::Migration[8.1]
  PRODUCT_TYPES = %w[
    book recorded_music video periodical game stationery gift cafe service other
  ].freeze

  def up
    harden_identifier_sequences!
    harden_products_and_variants!
    change_column :departments, :department_number, :string, using: "department_number::text" if department_number_integer?
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def harden_identifier_sequences!
    return if connection.primary_key(:identifier_sequences).present?

    execute <<~SQL.squish
      WITH ranked AS (
        SELECT ctid,
               namespace,
               ROW_NUMBER() OVER (
                 PARTITION BY namespace
                 ORDER BY next_value DESC, created_at DESC
               ) AS rn,
               MAX(next_value) OVER (PARTITION BY namespace) AS max_next
        FROM identifier_sequences
      )
      UPDATE identifier_sequences AS sequences
      SET next_value = ranked.max_next
      FROM ranked
      WHERE sequences.ctid = ranked.ctid
        AND ranked.rn = 1
    SQL

    execute <<~SQL.squish
      DELETE FROM identifier_sequences AS sequences
      USING (
        SELECT ctid,
               ROW_NUMBER() OVER (
                 PARTITION BY namespace
                 ORDER BY next_value DESC, created_at DESC
               ) AS rn
        FROM identifier_sequences
      ) ranked
      WHERE sequences.ctid = ranked.ctid
        AND ranked.rn > 1
    SQL

    execute "ALTER TABLE identifier_sequences ADD PRIMARY KEY (namespace)"
  end

  def harden_products_and_variants!
    # Backfill required catalog fields before adding null constraints.
    if table_exists?(:product_formats)
      execute <<~SQL.squish
        UPDATE products
        SET product_type = 'other'
        WHERE product_type IS NULL OR product_type = ''
      SQL

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
        raise "#{remaining} product(s) lack product_format_id and no format code 'other' exists for their organization."
      end
    end

    change_column_default :products, :sellable, from: true, to: false
    change_column_null :products, :product_type, false
    change_column_null :products, :product_format_id, false

    add_check_constraint :products,
                         "product_type IN (#{PRODUCT_TYPES.map { |t| "'#{t}'" }.join(", ")})",
                         name: "products_product_type_check",
                         if_not_exists: true

    unless foreign_key_exists?(:product_variants, :return_policies, column: :return_policy_id)
      add_foreign_key :product_variants, :return_policies, column: :return_policy_id, on_delete: :nullify
    end
    add_index :product_variants, :return_policy_id, if_not_exists: true

    add_check_constraint :return_policies,
                         "return_window_days IS NULL OR return_window_days >= 0",
                         name: "return_policies_return_window_days_non_negative",
                         if_not_exists: true

    add_check_constraint :discount_reasons,
                         "default_rate_bps IS NULL OR default_rate_bps >= 0",
                         name: "discount_reasons_default_rate_bps_non_negative",
                         if_not_exists: true
    add_check_constraint :discount_reasons,
                         "default_amount_cents IS NULL OR default_amount_cents >= 0",
                         name: "discount_reasons_default_amount_cents_non_negative",
                         if_not_exists: true
    add_check_constraint :discount_reasons,
                         "maximum_rate_bps IS NULL OR maximum_rate_bps >= 0",
                         name: "discount_reasons_maximum_rate_bps_non_negative",
                         if_not_exists: true
    add_check_constraint :discount_reasons,
                         "default_calculation_method IN ('percentage', 'fixed_amount', 'fixed_price')",
                         name: "discount_reasons_calculation_method_check",
                         if_not_exists: true

    add_check_constraint :products,
                         "available_from IS NULL OR available_until IS NULL OR available_from <= available_until",
                         name: "products_availability_window_order",
                         if_not_exists: true
    add_check_constraint :product_variants,
                         "available_from IS NULL OR available_until IS NULL OR available_from <= available_until",
                         name: "product_variants_availability_window_order",
                         if_not_exists: true
  end

  def department_number_integer?
    return false unless column_exists?(:departments, :department_number)

    columns(:departments).find { |c| c.name == "department_number" }.type == :integer
  end
end
