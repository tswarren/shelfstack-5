# frozen_string_literal: true

class EnforceOrganizationSingleton < ActiveRecord::Migration[8.1]
  def up
    if Organization.count > 1
      raise ActiveRecord::IrreversibleMigration,
            "INV-ORG-001: cannot enforce organization singleton while multiple organizations exist"
    end

    # Every row evaluates to the same constant, so at most one organization row may exist.
    add_index :organizations, "((true))", unique: true, name: "index_organizations_singleton"
  end

  def down
    remove_index :organizations, name: "index_organizations_singleton"
  end
end
