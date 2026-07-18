# frozen_string_literal: true

require "test_helper"

class AdministrativeAuditEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists audit events for administrators" do
    Administration::RecordAuditEvent.call(
      actor: users(:admin),
      organization: organizations(:acme),
      store: stores(:main_street),
      action: "user.updated",
      subject: users(:clerk),
      metadata: { "username" => "clerk" }
    )

    get administrative_audit_events_path
    assert_response :success
    assert_match "user.updated", response.body
  end

  test "denies clerk without audit view permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get administrative_audit_events_path
    assert_redirected_to root_path
  end
end
