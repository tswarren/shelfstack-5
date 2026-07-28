# frozen_string_literal: true

# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# (Administrator sync-on-reset only; do not silently re-grant on every seed).

unless defined?(PHASE11_1_PERMISSIONS)
  PHASE11_1_PERMISSIONS = [
    { code: "stored_value.activity.print", name: "Print stored-value activity slips", permission_group: "stored_value",
      description: "Print or reprint Stored-Value Activity Slips for completed ledger entries" },
    { code: "stored_value.voucher.print", name: "Print stored-value credit vouchers", permission_group: "stored_value",
      description: "Print or reprint Credit Vouchers for active Stored-Value Accounts" }
  ].freeze
end

PHASE11_1_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
