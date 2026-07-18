# frozen_string_literal: true

# Seeds are layered:
# 1) canonical reference data (always)
# 2) bootstrap installation (always; credentials from env outside development)
# 3) development sample data (development only)

load Rails.root.join("db/seeds/phase1_permissions.rb")

organization = Organization.find_or_initialize_by(code: "demo")
organization.assign_attributes(
  name: "Demo Bookstore",
  legal_name: "Demo Bookstore LLC",
  default_currency_code: "USD",
  default_timezone: "America/New_York",
  active: true
)
organization.save!

store = Store.find_or_initialize_by(organization: organization, code: "001")
store.assign_attributes(
  name: "Main Street",
  store_number: "1",
  timezone: organization.default_timezone,
  currency_code: organization.default_currency_code,
  active: true
)
store.save!

admin_role = Role.find_or_initialize_by(organization: organization, code: "administrator")
admin_role.assign_attributes(
  name: "Administrator",
  description: "Phase 1 administrator template",
  system_template: true,
  active: true
)
admin_role.save!

Permission.where(code: PHASE1_PERMISSIONS.map { |p| p[:code] }).find_each do |permission|
  RolePermission.find_or_create_by!(role: admin_role, permission: permission)
end

bootstrap_username = ENV.fetch("SHELFSTACK_BOOTSTRAP_USERNAME") do
  raise "SHELFSTACK_BOOTSTRAP_USERNAME is required outside development" unless Rails.env.development? || Rails.env.test?

  "admin"
end
bootstrap_password = ENV.fetch("SHELFSTACK_BOOTSTRAP_PASSWORD") do
  raise "SHELFSTACK_BOOTSTRAP_PASSWORD is required outside development" unless Rails.env.development? || Rails.env.test?

  "password123"
end

admin_user = User.find_or_initialize_by(username: bootstrap_username.to_s.strip.downcase)
if admin_user.new_record? || Rails.env.development? || Rails.env.test?
  admin_user.password = bootstrap_password
  admin_user.password_confirmation = bootstrap_password
end
admin_user.assign_attributes(
  first_name: "Bootstrap",
  last_name: "Admin",
  default_store: store,
  active: true,
  failed_login_attempts: 0
)
admin_user.save!

membership = StoreMembership.find_or_initialize_by(user: admin_user, store: store)
membership.assign_attributes(
  role: admin_role,
  active: true,
  starts_on: Date.current - 1.year,
  assigned_by_user: admin_user
)
membership.save!

if Rails.env.development?
  PosDevice.find_or_create_by!(store: store, code: "REG1") do |device|
    device.name = "Register 1"
    device.device_type = "register"
    device.active = true
  end

  CashDrawer.find_or_create_by!(store: store, code: "DRW1") do |drawer|
    drawer.name = "Drawer 1"
    drawer.active = true
  end
end
