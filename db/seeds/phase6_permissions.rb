# frozen_string_literal: true

# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# (Administrator sync-on-reset only; do not silently re-grant on every seed).

unless defined?(PHASE6_PERMISSIONS)
  PHASE6_PERMISSIONS = [
    { code: "pos.post_void.create", name: "Create post-void corrections", permission_group: "pos",
      description: "Create a full post-void reversing transaction" },
    { code: "pos.post_void.approve", name: "Approve post-void corrections", permission_group: "pos",
      description: "Independently approve another user's post-void" },
    { code: "pos.post_void.approve_self", name: "Self-approve post-void corrections", permission_group: "pos",
      description: "Authorize one's own post-void with recorded self-approval" },
    { code: "pos.return.refund_exception.approve", name: "Approve refund destination exceptions", permission_group: "pos",
      description: "Approve refunding to a destination other than a remaining original tender" },
    { code: "stored_value.account.view", name: "View stored-value accounts", permission_group: "stored_value",
      description: "View account and current balance" },
    { code: "stored_value.ledger.view", name: "View stored-value ledger", permission_group: "stored_value",
      description: "View ledger history" },
    { code: "stored_value.account.create", name: "Create stored-value accounts", permission_group: "stored_value",
      description: "Create zero-balance accounts" },
    { code: "stored_value.account.suspend", name: "Suspend stored-value accounts", permission_group: "stored_value",
      description: "Suspend or unsuspend accounts" },
    { code: "stored_value.issue", name: "Issue gift-card value", permission_group: "stored_value",
      description: "Issue gift-card value through POS" },
    { code: "stored_value.reload", name: "Reload gift-card value", permission_group: "stored_value",
      description: "Reload gift-card value through POS" },
    { code: "stored_value.tender.redeem", name: "Redeem stored value", permission_group: "stored_value",
      description: "Redeem stored value as tender" },
    { code: "stored_value.tender.refund", name: "Refund to stored value", permission_group: "stored_value",
      description: "Refund to stored value" },
    { code: "stored_value.adjustment.create", name: "Create stored-value adjustments", permission_group: "stored_value",
      description: "Create manual balance adjustments" },
    { code: "stored_value.adjustment.approve", name: "Approve stored-value adjustments", permission_group: "stored_value",
      description: "Independently approve manual adjustments" },
    { code: "stored_value.adjustment.approve_self", name: "Self-approve stored-value adjustments", permission_group: "stored_value",
      description: "Authorize one's own manual adjustment with recorded self-approval" }
  ].freeze
end

PHASE6_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
