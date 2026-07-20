# frozen_string_literal: true

require "test_helper"

module Administration
  class CreateCashDrawerTest < ActiveSupport::TestCase
    test "creates drawer and writes audit" do
      drawer = stores(:main_street).cash_drawers.new(code: "DRW9", name: "Drawer 9", active: true)

      assert_difference("AdministrativeAuditEvent.count") do
        assert CreateCashDrawer.call(
          drawer: drawer,
          actor: users(:admin),
          organization: organizations(:acme),
          store: stores(:main_street)
        )
      end

      assert drawer.persisted?
      assert_equal "drawer.created", AdministrativeAuditEvent.order(:id).last.action
    end

    test "returns false without audit when invalid" do
      drawer = stores(:main_street).cash_drawers.new(code: cash_drawers(:drawer_1).code, name: "Dup", active: true)

      assert_no_difference("AdministrativeAuditEvent.count") do
        refute CreateCashDrawer.call(
          drawer: drawer,
          actor: users(:admin),
          organization: organizations(:acme),
          store: stores(:main_street)
        )
      end
    end
  end
end
