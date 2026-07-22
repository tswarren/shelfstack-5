# frozen_string_literal: true

class AddVoidRequiredToPosTenders < ActiveRecord::Migration[8.1]
  def up
    add_column :pos_tenders, :recording_idempotency_key, :string
    add_index :pos_tenders, :recording_idempotency_key,
              unique: true,
              name: "index_pos_tenders_on_recording_idempotency_key_unique",
              where: "recording_idempotency_key IS NOT NULL"

    remove_check_constraint :pos_tenders, name: "pos_tenders_status_check"
    add_check_constraint :pos_tenders,
                         "status::text = ANY (ARRAY[" \
                         "'pending'::character varying::text, " \
                         "'authorized'::character varying::text, " \
                         "'completed'::character varying::text, " \
                         "'voided'::character varying::text, " \
                         "'removed'::character varying::text, " \
                         "'void_required'::character varying::text])",
                         name: "pos_tenders_status_check"
  end

  def down
    remove_check_constraint :pos_tenders, name: "pos_tenders_status_check"
    add_check_constraint :pos_tenders,
                         "status::text = ANY (ARRAY[" \
                         "'pending'::character varying::text, " \
                         "'authorized'::character varying::text, " \
                         "'completed'::character varying::text, " \
                         "'voided'::character varying::text, " \
                         "'removed'::character varying::text])",
                         name: "pos_tenders_status_check"

    remove_index :pos_tenders, name: "index_pos_tenders_on_recording_idempotency_key_unique"
    remove_column :pos_tenders, :recording_idempotency_key
  end
end
