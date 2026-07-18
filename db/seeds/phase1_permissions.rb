# frozen_string_literal: true

# Canonical Phase 1 permission definitions (idempotent upsert by code).
unless defined?(PHASE1_PERMISSIONS)
  PHASE1_PERMISSIONS = [
    { code: "administration.store.view", name: "View stores", permission_group: "administration", description: "View stores" },
    { code: "administration.store.manage", name: "Manage stores", permission_group: "administration", description: "Create/edit/deactivate stores" },
    { code: "administration.user.view", name: "View users", permission_group: "administration", description: "View users" },
    { code: "administration.user.manage", name: "Manage users", permission_group: "administration", description: "Create/edit/deactivate users" },
    { code: "administration.membership.manage", name: "Manage memberships", permission_group: "administration", description: "Manage store memberships and overrides" },
    { code: "administration.role.manage", name: "Manage roles", permission_group: "administration", description: "Manage roles and role-permission sets" },
    { code: "administration.permission.manage", name: "Manage permissions", permission_group: "administration", description: "Manage permission definitions (rare; unused in Phase 1 UI)" },
    { code: "administration.device.manage", name: "Manage devices", permission_group: "administration", description: "Manage POS devices" },
    { code: "administration.drawer.manage", name: "Manage drawers", permission_group: "administration", description: "Manage cash drawers" },
    { code: "administration.audit.view", name: "View audit", permission_group: "administration", description: "View administrative audit records" }
  ].freeze
end

PHASE1_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  # `code` is attr_readonly; find_or_initialize_by sets it only on create.
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
