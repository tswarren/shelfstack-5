# frozen_string_literal: true

# Canonical Phase 4a permission definitions (idempotent upsert by code).
# Source of truth: docs/domains/authorization-permissions.md (POS section, Phase 4a rows).
#
# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# so the administrator role picks up these new keys (see bootstrap-and-seed.md).
unless defined?(PHASE4A_PERMISSIONS)
  PHASE4A_PERMISSIONS = [
    { code: "pos.access", name: "Operate POS workspace", permission_group: "pos", description: "Operate POS workspace" },
    { code: "pos.business_day.open", name: "Open business day", permission_group: "pos", description: "Open business day" },
    { code: "pos.business_day.close", name: "Close business day", permission_group: "pos", description: "Close business day" },
    { code: "pos.session.open", name: "Open POS session", permission_group: "pos", description: "Open POS session" },
    { code: "pos.session.close", name: "Close POS session", permission_group: "pos", description: "Close POS session" },
    { code: "pos.transaction.open", name: "Open transactions", permission_group: "pos", description: "Open transactions" },
    { code: "pos.transaction.suspend", name: "Suspend transactions", permission_group: "pos", description: "Suspend transactions" },
    { code: "pos.transaction.recall", name: "Recall suspended transactions", permission_group: "pos", description: "Recall suspended transactions" },
    { code: "pos.transaction.cancel", name: "Cancel open/suspended transactions", permission_group: "pos", description: "Cancel open/suspended transactions" },
    { code: "pos.line.remove", name: "Remove pending lines", permission_group: "pos", description: "Remove pending lines" }
  ].freeze
end

PHASE4A_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
