# frozen_string_literal: true

# Canonical Phase 4d permission definitions (idempotent upsert by code).
# Source of truth: docs/domains/authorization-permissions.md (Inventory section, Phase 4d row).
#
# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# so the administrator role picks up these new keys (see bootstrap-and-seed.md).
unless defined?(PHASE4D_PERMISSIONS)
  PHASE4D_PERMISSIONS = [
    { code: "inventory.unit.manage", name: "Create/manage inventory units", permission_group: "inventory",
      description: "Create/manage inventory units" }
  ].freeze
end

PHASE4D_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
