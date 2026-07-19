# frozen_string_literal: true

# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# (Administrator sync-on-reset only; do not silently re-grant on every seed).

unless defined?(PHASE4E_PERMISSIONS)
  PHASE4E_PERMISSIONS = [
    { code: "pos.return.create", name: "Create return lines", permission_group: "pos",
      description: "Create linked return lines" },
    # Seeded ahead of its unlinked/no-receipt return service (deferred beyond
    # Phase 4e's linked-return scope) so the permission key exists per
    # docs/domains/authorization-permissions.md without inventing the workflow.
    { code: "pos.return.no_receipt", name: "No-receipt returns", permission_group: "pos",
      description: "Create unlinked no-receipt returns" }
  ].freeze
end

PHASE4E_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
