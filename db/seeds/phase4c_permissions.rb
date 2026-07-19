# frozen_string_literal: true

# Canonical Phase 4c permission definitions (idempotent upsert by code).
# Source of truth: docs/domains/authorization-permissions.md (POS section, Phase 4c rows).
#
# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# so the administrator role picks up these new keys (see bootstrap-and-seed.md).
unless defined?(PHASE4C_PERMISSIONS)
  PHASE4C_PERMISSIONS = [
    { code: "pos.transaction.complete", name: "Complete transactions", permission_group: "pos",
      description: "Complete transactions" },
    { code: "pos.tender.cash", name: "Accept cash tenders", permission_group: "pos",
      description: "Accept cash tenders" },
    { code: "pos.tender.card_standalone", name: "Record standalone card tenders", permission_group: "pos",
      description: "Record standalone card tenders" },
    { code: "pos.tender.card_void", name: "Confirm external card tender voids", permission_group: "pos",
      description: "Confirm external terminal void for authorized card tenders" },
    { code: "pos.cash_movement.create", name: "Paid-in / paid-out / drops", permission_group: "pos",
      description: "Paid-in / paid-out / drops" },
    { code: "pos.receipt.reprint", name: "Reprint receipts", permission_group: "pos",
      description: "Reprint receipts" }
  ].freeze
end

PHASE4C_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
