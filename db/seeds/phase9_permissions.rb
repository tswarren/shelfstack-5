# frozen_string_literal: true

unless defined?(PHASE9_PERMISSIONS)
  PHASE9_PERMISSIONS = [
    { code: "customers.customer.view", name: "View customers", permission_group: "customers",
      description: "View Customer records" },
    { code: "customers.customer.create", name: "Create customers", permission_group: "customers",
      description: "Create Customer records" },
    { code: "customers.customer.edit", name: "Edit customers", permission_group: "customers",
      description: "Edit Customer records" },
    { code: "customers.customer.deactivate", name: "Deactivate customers", permission_group: "customers",
      description: "Deactivate Customer records" }
  ].freeze
end

PHASE9_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
