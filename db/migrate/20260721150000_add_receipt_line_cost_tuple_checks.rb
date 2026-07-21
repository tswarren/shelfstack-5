# frozen_string_literal: true

class AddReceiptLineCostTupleChecks < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE receipt_lines
      SET cost_provenance = 'manual_receipt'
      WHERE cost_provenance IS NOT NULL
        AND cost_provenance NOT IN (
          'purchase_order_expected',
          'purchase_order_list_discount',
          'vendor_source_expected',
          'vendor_list_discount',
          'manual_receipt',
          'unknown',
          'confirmed_zero'
        )
    SQL

    execute <<~SQL.squish
      ALTER TABLE receipt_lines
        ADD CONSTRAINT receipt_lines_cost_provenance_check
        CHECK (
          cost_provenance IS NULL OR cost_provenance IN (
            'purchase_order_expected',
            'purchase_order_list_discount',
            'vendor_source_expected',
            'vendor_list_discount',
            'manual_receipt',
            'unknown',
            'confirmed_zero'
          )
        )
    SQL

    execute <<~SQL.squish
      ALTER TABLE receipt_lines
        ADD CONSTRAINT receipt_lines_cost_unknown_tuple_check
        CHECK (
          cost_quality IS DISTINCT FROM 'unknown'
          OR (
            actual_unit_cost_cents IS NULL
            AND cost_provenance = 'unknown'
          )
        )
    SQL

    execute <<~SQL.squish
      ALTER TABLE receipt_lines
        ADD CONSTRAINT receipt_lines_cost_confirmed_zero_tuple_check
        CHECK (
          cost_quality IS DISTINCT FROM 'confirmed_zero'
          OR (
            actual_unit_cost_cents = 0
            AND cost_provenance = 'confirmed_zero'
          )
        )
    SQL
  end

  def down
    execute "ALTER TABLE receipt_lines DROP CONSTRAINT IF EXISTS receipt_lines_cost_confirmed_zero_tuple_check"
    execute "ALTER TABLE receipt_lines DROP CONSTRAINT IF EXISTS receipt_lines_cost_unknown_tuple_check"
    execute "ALTER TABLE receipt_lines DROP CONSTRAINT IF EXISTS receipt_lines_cost_provenance_check"
  end
end
