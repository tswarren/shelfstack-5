# frozen_string_literal: true

require "test_helper"

module Pos
  class PendingApprovalActionTest < ActiveSupport::TestCase
    test "store and load round-trip preserves fingerprint and presentation" do
      session = {}
      PendingApprovalAction.store(
        session,
        action: "price_override",
        fingerprint: "abc123",
        payload: { "requested_unit_price_cents" => 1200 },
        presentation: PendingApprovalAction::Presentation.new(
          title: "Approval required",
          action_summary: "Price override",
          boundary: "Limit $5.00",
          material_values: "$18.00 → $12.00",
          effect: "Line unit price becomes $12.00"
        )
      )

      pending = PendingApprovalAction.load(session)
      assert pending
      assert_equal "price_override", pending.action
      assert pending.matches_fingerprint?("abc123")
      refute pending.matches_fingerprint?("other")
      assert_equal "Price override", pending.presentation.action_summary

      PendingApprovalAction.clear!(session)
      assert_nil PendingApprovalAction.load(session)
    end
  end
end
