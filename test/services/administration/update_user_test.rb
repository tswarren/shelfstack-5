# frozen_string_literal: true

require "test_helper"

module Administration
  class UpdateUserTest < ActiveSupport::TestCase
    test "password change sets password_changed_at and audit flag without storing secrets" do
      user = users(:clerk)

      assert UpdateUser.call(
        user: user,
        attributes: {
          first_name: user.first_name,
          password: "newpassword123",
          password_confirmation: "newpassword123"
        },
        actor: users(:admin),
        organization: organizations(:acme),
        store: stores(:main_street)
      )

      user.reload
      assert user.password_changed_at.present?
      event = AdministrativeAuditEvent.order(:id).last
      assert_equal true, event.metadata["password_changed"]
      assert_nil event.metadata["password"]
      assert_nil event.metadata["password_digest"]
      refute_includes event.metadata.to_s, "newpassword123"
    end
  end
end
