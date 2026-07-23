# frozen_string_literal: true

# After seeding, existing installs need `bin/rails shelfstack:sync_admin_permissions`
# (Administrator sync-on-reset only; do not silently re-grant on every seed).

unless defined?(PHASE7_PERMISSIONS)
  PHASE7_PERMISSIONS = [
    { code: "reporting.view_sales", name: "View sales reports", permission_group: "reporting",
      description: "View commercial / sales reports" },
    { code: "reporting.view_tax", name: "View tax reports", permission_group: "reporting",
      description: "View tax reports" },
    { code: "reporting.view_tenders", name: "View tender reports", permission_group: "reporting",
      description: "View tender reports" },
    { code: "reporting.view_cash", name: "View cash reports", permission_group: "reporting",
      description: "View cash accountability and expected cash on X/Z reports" },
    { code: "reporting.view_inventory", name: "View inventory reports", permission_group: "reporting",
      description: "View inventory quantity and movement reports" },
    { code: "reporting.view_purchasing", name: "View purchasing reports", permission_group: "reporting",
      description: "View purchasing and receiving operational reports" },
    { code: "reporting.view_requests", name: "View request reports", permission_group: "reporting",
      description: "View product-request reports" },
    { code: "reporting.view_cost", name: "View cost on reports", permission_group: "reporting",
      description: "View cost figures on reports" },
    { code: "reporting.view_margin", name: "View margin on reports", permission_group: "reporting",
      description: "View margin figures on reports" },
    { code: "reporting.view_stored_value", name: "View stored-value reports", permission_group: "reporting",
      description: "View stored-value liability and activity reports" },
    { code: "reporting.view_audit", name: "View audit reports", permission_group: "reporting",
      description: "View audit and exception report packs" },
    { code: "reporting.view_session_x", name: "View Session X", permission_group: "reporting",
      description: "View Session X reports" },
    { code: "reporting.view_session_z", name: "View Session Z", permission_group: "reporting",
      description: "View Session Z reports" },
    { code: "reporting.view_business_day_x", name: "View Business-Day X", permission_group: "reporting",
      description: "View Business-Day X reports" },
    { code: "reporting.view_business_day_z", name: "View Business-Day Z", permission_group: "reporting",
      description: "View Business-Day Z reports" },
    { code: "reporting.export", name: "Export reports", permission_group: "reporting",
      description: "Export tabular reports such as CSV" },
    { code: "reporting.reconcile_session", name: "Reconcile POS sessions", permission_group: "reporting",
      description: "Draft and finalize session reconciliation" },
    { code: "reporting.reconcile_business_day", name: "Reconcile business days", permission_group: "reporting",
      description: "Draft and finalize business-day reconciliation" },
    { code: "reporting.record_reconciliation_resolution", name: "Record reconciliation resolutions", permission_group: "reporting",
      description: "Record reconciliation resolutions including accept-exception" },
    { code: "reporting.close_evidence_unavailable", name: "Record unavailable close evidence", permission_group: "reporting",
      description: "Record evidence_unavailable at close without fabricating observed amounts" },
    { code: "reporting.reconcile.approve", name: "Approve reconciliation variances", permission_group: "reporting",
      description: "Independently approve over-threshold variance acceptance" },
    { code: "reporting.reconcile.approve_self", name: "Self-approve reconciliation variances", permission_group: "reporting",
      description: "Self-approve over-threshold variance acceptance with re-authentication" }
  ].freeze
end

PHASE7_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
