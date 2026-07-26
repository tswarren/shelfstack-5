# frozen_string_literal: true

class CreateCustomersAndNamespace22 < ActiveRecord::Migration[8.1]
  def up
    create_table :customers do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :customer_number, null: false
      t.string :customer_type, null: false
      t.string :organization_name
      t.string :first_name
      t.string :last_name
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country_code
      t.string :primary_phone
      t.string :alternate_phone
      t.string :primary_email
      t.string :alternate_email
      t.string :preferred_contact_method, null: false, default: "none"
      t.text :notes
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :customers, :customer_number, unique: true
    add_index :customers, :primary_phone, where: "primary_phone IS NOT NULL",
              name: "index_customers_on_primary_phone_partial"
    add_index :customers, :alternate_phone, where: "alternate_phone IS NOT NULL",
              name: "index_customers_on_alternate_phone_partial"
    add_index :customers, :primary_email, where: "primary_email IS NOT NULL",
              name: "index_customers_on_primary_email_partial"
    add_index :customers, :alternate_email, where: "alternate_email IS NOT NULL",
              name: "index_customers_on_alternate_email_partial"
    add_index :customers, [ :organization_id, :active ]

    add_check_constraint :customers,
      "customer_type IN ('individual', 'organization')",
      name: "customers_customer_type_check"
    add_check_constraint :customers,
      "preferred_contact_method IN ('phone', 'email', 'none')",
      name: "customers_preferred_contact_method_check"

    remove_check_constraint :identifier_sequences, name: "identifier_sequences_namespace_check"
    add_check_constraint :identifier_sequences,
      "namespace::text = ANY (ARRAY['21'::character varying::text, '22'::character varying::text, '27'::character varying::text, '28'::character varying::text, '29'::character varying::text])",
      name: "identifier_sequences_namespace_check"

    execute <<~SQL.squish
      INSERT INTO identifier_sequences (namespace, next_value, created_at, updated_at)
      VALUES ('22', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (namespace) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM identifier_sequences WHERE namespace = '22'"
    remove_check_constraint :identifier_sequences, name: "identifier_sequences_namespace_check"
    add_check_constraint :identifier_sequences,
      "namespace::text = ANY (ARRAY['21'::character varying::text, '27'::character varying::text, '28'::character varying::text, '29'::character varying::text])",
      name: "identifier_sequences_namespace_check"
    drop_table :customers
  end
end
