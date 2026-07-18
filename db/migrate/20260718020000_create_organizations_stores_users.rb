# frozen_string_literal: true

class CreateOrganizationsStoresUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :legal_name
      t.string :default_currency_code, null: false, limit: 3
      t.string :default_timezone, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :organizations, :code, unique: true

    create_table :stores do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :store_number
      t.string :name, null: false
      t.string :legal_name
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :region
      t.string :postal_code, limit: 12
      t.string :country_code, limit: 2
      t.string :phone, limit: 30
      t.string :email
      t.string :san_number, limit: 8
      t.string :timezone, null: false
      t.string :currency_code, null: false, limit: 3
      t.text :receipt_header
      t.text :receipt_footer
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :stores, [ :organization_id, :code ], unique: true
    add_index :stores, [ :organization_id, :store_number ], unique: true, where: "store_number IS NOT NULL"

    create_table :users do |t|
      t.string :username, null: false
      t.integer :user_number
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :password_digest, null: false
      t.string :pin_digest
      t.references :default_store, foreign_key: { to_table: :stores, on_delete: :nullify }
      t.boolean :active, null: false, default: true
      t.datetime :locked_at
      t.datetime :last_login_at
      t.integer :failed_login_attempts, null: false, default: 0
      t.datetime :password_changed_at
      t.datetime :pin_changed_at

      t.timestamps
    end
    # Usernames are normalized to lowercase before save; lower() index enforces case-insensitive uniqueness.
    add_index :users, "lower((username)::text)", unique: true, name: "index_users_on_lower_username"
    add_index :users, :user_number, unique: true, where: "user_number IS NOT NULL"

    add_check_constraint :users, "failed_login_attempts >= 0", name: "users_failed_login_attempts_non_negative"
  end
end
