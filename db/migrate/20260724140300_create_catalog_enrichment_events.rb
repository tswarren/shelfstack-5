# frozen_string_literal: true

# Gate 8b Slice 1 (OD-P8-09): append-only import-provenance contract. Schema
# and immutability ship in 8b; writers arrive in 8c/8f once external metadata
# successfully applies. No `updated_at` -- events are never edited, only
# superseded by later events (CatalogEnrichmentEvent#readonly? enforces this).
# Associations use restrictive delete: a Product, Organization, or User
# referenced by an enrichment event must not be silently cascade-deleted.
class CreateCatalogEnrichmentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_enrichment_events do |t|
      t.references :product, null: false, foreign_key: { on_delete: :restrict }
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.references :actor_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :provider, null: false
      t.string :provider_record_id
      t.string :requested_identifier, null: false
      t.string :canonical_identifier, null: false
      t.string :action, null: false
      t.datetime :retrieved_at, null: false
      t.datetime :created_at, null: false
      t.jsonb :applied_fields, null: false, default: {}
      t.jsonb :accepted_warnings, null: false, default: []
    end

    add_check_constraint :catalog_enrichment_events,
                         "action IN ('create', 'fill_empty', 'selected_apply')",
                         name: "catalog_enrichment_events_action_allowed"

    add_index :catalog_enrichment_events, [ :product_id, :created_at ]
    add_index :catalog_enrichment_events, [ :organization_id, :created_at ]
    add_index :catalog_enrichment_events, [ :provider, :provider_record_id ]
    add_index :catalog_enrichment_events, [ :canonical_identifier ]
  end
end
