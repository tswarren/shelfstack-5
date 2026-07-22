# frozen_string_literal: true

class HardenCardRefundReconciliation < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      DROP CONSTRAINT pos_card_refund_preps_state_shape
    SQL
    # recorded_orphan may retain abandoned_at/abandoned_by when auth arrives after abandon.
    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      ADD CONSTRAINT pos_card_refund_preps_state_shape
      CHECK (
        (status = 'prepared' AND authorization_code IS NULL AND consumed_at IS NULL
          AND pos_tender_id IS NULL AND abandoned_at IS NULL)
        OR (status = 'recorded_tender' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
          AND pos_tender_id IS NOT NULL AND abandoned_at IS NULL)
        OR (status = 'recorded_orphan' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
          AND pos_tender_id IS NULL)
        OR (status = 'abandoned' AND abandoned_at IS NOT NULL AND authorization_code IS NULL
          AND pos_tender_id IS NULL AND consumed_at IS NULL)
      )
    SQL

    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      DROP CONSTRAINT pos_card_refund_preps_resolution_kind_check
    SQL
    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      ADD CONSTRAINT pos_card_refund_preps_resolution_kind_check
      CHECK (
        resolution_kind IS NULL OR resolution_kind IN (
          'externally_voided', 'validated_and_accepted', 'replaced',
          'external_void_confirmed', 'accepted_financial_exception'
        )
      )
    SQL

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
        'stored_value_refund_exception'::character varying,
        'card_refund_reconciliation'::character varying
      ]::text[]))
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      DROP CONSTRAINT pos_card_refund_preps_state_shape
    SQL
    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      ADD CONSTRAINT pos_card_refund_preps_state_shape
      CHECK (
        (status = 'prepared' AND authorization_code IS NULL AND consumed_at IS NULL
          AND pos_tender_id IS NULL AND abandoned_at IS NULL)
        OR (status = 'recorded_tender' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
          AND pos_tender_id IS NOT NULL AND abandoned_at IS NULL)
        OR (status = 'recorded_orphan' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
          AND pos_tender_id IS NULL AND abandoned_at IS NULL)
        OR (status = 'abandoned' AND abandoned_at IS NOT NULL AND authorization_code IS NULL
          AND pos_tender_id IS NULL AND consumed_at IS NULL)
      )
    SQL

    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      DROP CONSTRAINT pos_card_refund_preps_resolution_kind_check
    SQL
    execute <<~SQL.squish
      ALTER TABLE pos_card_refund_preparations
      ADD CONSTRAINT pos_card_refund_preps_resolution_kind_check
      CHECK (
        resolution_kind IS NULL OR resolution_kind IN (
          'externally_voided', 'validated_and_accepted', 'replaced',
          'external_void_confirmed', 'linked_to_correcting_transaction',
          'accepted_financial_exception'
        )
      )
    SQL

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
end
