# frozen_string_literal: true

# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# (Administrator sync-on-reset only; do not silently re-grant on every seed).
#
# Gate 8b Slice 1 only. `create_from_enrichment` / `enrich_product` /
# `replace_enriched_fields` are deferred to Gates 8c/8f (phase-08 §9).

unless defined?(PHASE8_PERMISSIONS)
  PHASE8_PERMISSIONS = [
    { code: "catalog.lookup_external", name: "Look up external metadata", permission_group: "catalog",
      description: "Query provider-neutral external bibliographic metadata (Gate 8b service boundary; no lookup endpoint ships in 8b)" },
    { code: "catalog.manage_creators", name: "Manage creators", permission_group: "catalog",
      description: "Create, rename, and deactivate Creator master records" }
  ].freeze
end

PHASE8_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
