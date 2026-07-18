# frozen_string_literal: true

# Canonical Phase 2 permission definitions (idempotent upsert by code).
unless defined?(PHASE2_PERMISSIONS)
  PHASE2_PERMISSIONS = [
    { code: "classification.view", name: "View classification masters", permission_group: "classification", description: "View classification masters" },
    { code: "classification.merchandise_class.manage", name: "Manage merchandise classes", permission_group: "classification", description: "Manage merchandise classes" },
    { code: "classification.department.manage", name: "Manage departments", permission_group: "classification", description: "Manage departments" },
    { code: "classification.tax_category.manage", name: "Manage tax categories", permission_group: "classification", description: "Manage tax categories" },
    { code: "classification.store_tax_rule.manage", name: "Manage store tax rates/rules", permission_group: "classification", description: "Manage store tax rates/rules" },
    { code: "classification.return_policy.manage", name: "Manage return policies", permission_group: "classification", description: "Manage return policies" },
    { code: "classification.reason.manage", name: "Manage reason catalogs", permission_group: "classification", description: "Manage return and discount reasons" },
    { code: "classification.tender_type.manage", name: "Manage tender types", permission_group: "classification", description: "Manage tender types" },
    { code: "classification.store_configuration.manage", name: "Manage store operating settings", permission_group: "classification", description: "Manage store operating settings" },
    { code: "catalog.product.view", name: "View products and variants", permission_group: "catalog", description: "View products and variants" },
    { code: "catalog.product.create", name: "Create products", permission_group: "catalog", description: "Create products" },
    { code: "catalog.product.edit", name: "Edit products", permission_group: "catalog", description: "Edit products" },
    { code: "catalog.product.deactivate", name: "Deactivate products", permission_group: "catalog", description: "Deactivate products" },
    { code: "catalog.identifier.correct", name: "Correct canonical identifiers", permission_group: "catalog", description: "Controlled canonical identifier correction" },
    { code: "catalog.variant.create", name: "Create variants", permission_group: "catalog", description: "Create variants" },
    { code: "catalog.variant.edit", name: "Edit variants", permission_group: "catalog", description: "Edit variants including price and tracking mode" },
    { code: "catalog.variant.deactivate", name: "Deactivate variants", permission_group: "catalog", description: "Deactivate variants" },
    { code: "catalog.option.manage", name: "Manage option structures", permission_group: "catalog", description: "Manage option structures" },
    { code: "catalog.format.manage", name: "Manage product formats", permission_group: "catalog", description: "Manage product formats" },
    { code: "catalog.condition.manage", name: "Manage product conditions", permission_group: "catalog", description: "Manage product conditions" },
    { code: "catalog.label.print", name: "Print labels", permission_group: "catalog", description: "Print labels" }
  ].freeze
end

PHASE2_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
