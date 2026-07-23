# frozen_string_literal: true

class AddStoredValueRefundExceptionApprovalType < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      ALTER TABLE pos_approvals
      DROP CONSTRAINT pos_approvals_action_type_check
    SQL
    execute <<~SQL.squish
      ALTER TABLE pos_approvals
      ADD CONSTRAINT pos_approvals_action_type_check
      CHECK (action_type::text = ANY (ARRAY[
        'price_override'::character varying,
        'discount_apply'::character varying,
        'tax_exemption'::character varying,
        'tax_category_override'::character varying,
        'cash_movement'::character varying,
        'post_void'::character varying,
        'stored_value_adjustment'::character varying,
        'stored_value_refund_exception'::character varying
      ]::text[]))
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE pos_approvals
      DROP CONSTRAINT pos_approvals_action_type_check
    SQL
    execute <<~SQL.squish
      ALTER TABLE pos_approvals
      ADD CONSTRAINT pos_approvals_action_type_check
      CHECK (action_type::text = ANY (ARRAY[
        'price_override'::character varying,
        'discount_apply'::character varying,
        'tax_exemption'::character varying,
        'tax_category_override'::character varying,
        'cash_movement'::character varying,
        'post_void'::character varying,
        'stored_value_adjustment'::character varying
      ]::text[]))
    SQL
  end
end
