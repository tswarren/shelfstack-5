# frozen_string_literal: true

# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# (Administrator sync-on-reset only; do not silently re-grant on every seed).

unless defined?(PHASE11_PERMISSIONS)
  PHASE11_PERMISSIONS = [
    { code: "pos.no_sale.create", name: "Record No Sale", permission_group: "pos",
      description: "Record an audited No Sale event for an open cash-enabled POS session" },
    { code: "pos.product_request.pickup", name: "POS Product Request pickup", permission_group: "pos",
      description: "Search fulfillable Customer Requests and add eligible pickup quantity on POS" }
  ].freeze
end

PHASE11_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
