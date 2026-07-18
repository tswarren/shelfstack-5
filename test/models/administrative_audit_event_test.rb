# frozen_string_literal: true

require "test_helper"

class AdministrativeAuditEventTest < ActiveSupport::TestCase
  test "creates append-only events" do
    event = AdministrativeAuditEvent.create!(
      actor_user: users(:admin),
      organization: organizations(:acme),
      store: stores(:main_street),
      action: "store.updated",
      subject_type: "Store",
      subject_id: stores(:main_street).id,
      metadata: { code: "001" },
      created_at: Time.current
    )

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.update!(action: "store.created")
    end

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.destroy!
    end
  end
end
