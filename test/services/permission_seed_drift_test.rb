# frozen_string_literal: true

require "test_helper"

# Phase 4g-2: every permission key enforced by controllers/services must be seeded.
class PermissionSeedDriftTest < ActiveSupport::TestCase
  test "seeded permissions include every require_permission key used in controllers" do
    enforced = Dir[Rails.root.join("app/controllers/**/*.rb")].flat_map do |path|
      File.read(path).scan(/require_permission!\(\s*"([^"]+)"/).flatten
    end.uniq.sort

    seeded = Permission.order(:code).pluck(:code)
    missing = enforced - seeded

    assert_empty missing, "Permission keys enforced in controllers but missing from seeds/fixtures: #{missing.join(', ')}"
  end

  test "administrator sync grants all seeded permissions for the organization" do
    role = roles(:administrator)
    Administration::SyncAdministratorPermissions.call(
      role: role,
      actor: users(:admin),
      organization: organizations(:acme),
      store: stores(:main_street)
    )

    granted = role.reload.permissions.pluck(:code).sort
    expected = Permission.pluck(:code).sort
    assert_equal expected, granted
  end
end
