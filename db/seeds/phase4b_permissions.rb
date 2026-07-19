# frozen_string_literal: true

# Canonical Phase 4b permission definitions (idempotent upsert by code).
# Source of truth: docs/domains/authorization-permissions.md (POS section, Phase 4b rows).
#
# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# so the administrator role picks up these new keys (see bootstrap-and-seed.md).
unless defined?(PHASE4B_PERMISSIONS)
  PHASE4B_PERMISSIONS = [
    { code: "pos.price.override", name: "Override selling price", permission_group: "pos",
      description: "Override selling price" },
    { code: "pos.discount.apply", name: "Apply discounts", permission_group: "pos",
      description: "Apply discounts" },
    { code: "pos.discount.approve", name: "Approve discounts beyond requester authority", permission_group: "pos",
      description: "Approve discounts beyond requester authority" },
    { code: "pos.tax.exempt", name: "Apply whole-transaction tax exemption", permission_group: "pos",
      description: "Apply whole-transaction tax exemption" },
    { code: "pos.tax_category.override", name: "Override effective Tax Category on a POS line",
      permission_group: "pos", description: "Override effective Tax Category on a POS line" }
  ].freeze
end

PHASE4B_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
