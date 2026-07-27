# frozen_string_literal: true

class AllowUnlinkedPosReturnLines < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :pos_line_items, name: "pos_line_items_return_requires_link"
    add_check_constraint :pos_line_items, <<~SQL.squish, name: "pos_line_items_return_requires_link"
      direction::text = 'sale'::text
      OR reverses_pos_line_item_id IS NOT NULL
      OR (
        return_reason_id IS NOT NULL
        AND return_disposition IS NOT NULL
        AND (
          original_pos_line_item_id IS NOT NULL
          OR return_source::text = ANY (
            ARRAY[
              'external_receipt'::character varying,
              'gift_receipt'::character varying,
              'no_receipt'::character varying
            ]::text[]
          )
        )
      )
    SQL

    remove_check_constraint :pos_approvals, name: "pos_approvals_action_type_check"
    add_check_constraint :pos_approvals, <<~SQL.squish, name: "pos_approvals_action_type_check"
      action_type::text = ANY (
        ARRAY[
          'price_override'::character varying,
          'discount_apply'::character varying,
          'tax_exemption'::character varying,
          'tax_category_override'::character varying,
          'cash_movement'::character varying,
          'post_void'::character varying,
          'stored_value_adjustment'::character varying,
          'stored_value_refund_exception'::character varying,
          'card_refund_reconciliation'::character varying,
          'reconciliation_variance'::character varying,
          'no_receipt_return'::character varying
        ]::text[]
      )
    SQL
  end

  def down
    remove_check_constraint :pos_approvals, name: "pos_approvals_action_type_check"
    add_check_constraint :pos_approvals, <<~SQL.squish, name: "pos_approvals_action_type_check"
      action_type::text = ANY (
        ARRAY[
          'price_override'::character varying,
          'discount_apply'::character varying,
          'tax_exemption'::character varying,
          'tax_category_override'::character varying,
          'cash_movement'::character varying,
          'post_void'::character varying,
          'stored_value_adjustment'::character varying,
          'stored_value_refund_exception'::character varying,
          'card_refund_reconciliation'::character varying,
          'reconciliation_variance'::character varying
        ]::text[]
      )
    SQL

    remove_check_constraint :pos_line_items, name: "pos_line_items_return_requires_link"
    add_check_constraint :pos_line_items, <<~SQL.squish, name: "pos_line_items_return_requires_link"
      direction::text = 'sale'::text
      OR reverses_pos_line_item_id IS NOT NULL
      OR (
        original_pos_line_item_id IS NOT NULL
        AND return_reason_id IS NOT NULL
        AND return_disposition IS NOT NULL
      )
    SQL
  end
end
