# frozen_string_literal: true

# Canonical Phase 3 permission definitions (idempotent upsert by code).
unless defined?(PHASE3_PERMISSIONS)
  PHASE3_PERMISSIONS = [
    { code: "inventory.stock.view", name: "View store stock balances", permission_group: "inventory", description: "View store stock balances" },
    { code: "inventory.cost.view", name: "View inventory cost", permission_group: "inventory", description: "View inventory cost" },
    { code: "inventory.adjustment.create", name: "Create draft adjustments", permission_group: "inventory", description: "Create draft inventory adjustments" },
    { code: "inventory.adjustment.post", name: "Post opening and quantity-only adjustments", permission_group: "inventory", description: "Post opening and quantity-only adjustments" },
    { code: "inventory.cost_correction.post", name: "Post inventory cost corrections", permission_group: "inventory", description: "Post inventory cost corrections" },
    { code: "inventory.reservation.view", name: "Review reservations", permission_group: "inventory", description: "Review inventory reservations" },
    { code: "inventory.reservation.release", name: "Release active reservations", permission_group: "inventory", description: "Release active inventory reservations" }
  ].freeze
end

PHASE3_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
