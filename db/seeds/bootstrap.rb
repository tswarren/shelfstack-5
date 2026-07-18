# frozen_string_literal: true

# Explicit installation bootstrap. Invoked by `bin/rails shelfstack:bootstrap`.
# Creates org/store/admin role/user/membership when missing.
# Never reactivates disabled access or clears lockout counters on existing records.

load Rails.root.join("db/seeds/phase1_permissions.rb")

development_like = Rails.env.development? || Rails.env.test?

org_code = ENV.fetch("SHELFSTACK_BOOTSTRAP_ORG_CODE") do
  development_like ? "demo" : (raise "SHELFSTACK_BOOTSTRAP_ORG_CODE is required")
end
org_name = ENV.fetch("SHELFSTACK_BOOTSTRAP_ORG_NAME") do
  development_like ? "Demo Bookstore" : (raise "SHELFSTACK_BOOTSTRAP_ORG_NAME is required")
end
store_code = ENV.fetch("SHELFSTACK_BOOTSTRAP_STORE_CODE") do
  development_like ? "001" : (raise "SHELFSTACK_BOOTSTRAP_STORE_CODE is required")
end
store_name = ENV.fetch("SHELFSTACK_BOOTSTRAP_STORE_NAME") do
  development_like ? "Main Street" : (raise "SHELFSTACK_BOOTSTRAP_STORE_NAME is required")
end
timezone = ENV.fetch("SHELFSTACK_BOOTSTRAP_TIMEZONE", "America/New_York")
currency = ENV.fetch("SHELFSTACK_BOOTSTRAP_CURRENCY", "USD")

bootstrap_username = ENV.fetch("SHELFSTACK_BOOTSTRAP_USERNAME") do
  raise "SHELFSTACK_BOOTSTRAP_USERNAME is required outside development" unless development_like

  "admin"
end
bootstrap_password = ENV.fetch("SHELFSTACK_BOOTSTRAP_PASSWORD") do
  raise "SHELFSTACK_BOOTSTRAP_PASSWORD is required outside development" unless development_like

  "password123"
end

organization = Organization.find_or_initialize_by(code: org_code)
if organization.new_record?
  organization.assign_attributes(
    name: org_name,
    legal_name: ENV.fetch("SHELFSTACK_BOOTSTRAP_ORG_LEGAL_NAME", org_name),
    default_currency_code: currency,
    default_timezone: timezone,
    active: true
  )
  organization.save!
end

store = Store.find_or_initialize_by(organization: organization, code: store_code)
if store.new_record?
  store.assign_attributes(
    name: store_name,
    store_number: ENV.fetch("SHELFSTACK_BOOTSTRAP_STORE_NUMBER", "1"),
    timezone: organization.default_timezone,
    currency_code: organization.default_currency_code,
    active: true
  )
  store.save!
end

admin_role = Role.find_or_initialize_by(organization: organization, code: "administrator")
if admin_role.new_record?
  admin_role.assign_attributes(
    name: "Administrator",
    description: "Bootstrap administrator template",
    system_template: true,
    active: true
  )
  admin_role.save!
end

Permission.find_each do |permission|
  RolePermission.find_or_create_by!(role: admin_role, permission: permission)
end

admin_user = User.find_or_initialize_by(username: bootstrap_username.to_s.strip.downcase)
if admin_user.new_record?
  admin_user.password = bootstrap_password
  admin_user.password_confirmation = bootstrap_password
  admin_user.assign_attributes(
    first_name: "Bootstrap",
    last_name: "Admin",
    default_store: store,
    active: true,
    failed_login_attempts: 0
  )
  admin_user.save!
elsif development_like && ENV["SHELFSTACK_BOOTSTRAP_RESET_PASSWORD"] == "1"
  admin_user.password = bootstrap_password
  admin_user.password_confirmation = bootstrap_password
  admin_user.save!
end

membership = StoreMembership.find_or_initialize_by(user: admin_user, store: store)
if membership.new_record?
  membership.assign_attributes(
    role: admin_role,
    active: true,
    starts_on: Date.current - 1.year,
    assigned_by_user: admin_user
  )
  membership.save!
end

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

puts "Bootstrap complete for organization=#{organization.code} store=#{store.code} user=#{admin_user.username}"
