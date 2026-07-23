# frozen_string_literal: true

require "test_helper"

module Pos
  class AuthorizeActionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @catalog_editor = users(:catalog_editor)
    end

    test "allows outright when the requester holds the permission and no limit_key is given" do
      result = AuthorizeAction.call(
        store: @store, requester: @admin, permission_key: "pos.tax.exempt", action_type: "tax_exemption"
      )

      assert result.allowed?
      assert_equal :allowed, result.status
      assert_nil result.pos_approval
    end

    test "requester within their own numeric authority is allowed without an approval record" do
      result = AuthorizeAction.call(
        store: @store, requester: @admin, permission_key: "pos.discount.apply", action_type: "discount_apply",
        limit_key: :maximum_discount_amount_cents, requested_value: 5000
      )

      assert result.allowed?
      assert_equal :allowed, result.status
      assert_nil result.pos_approval
    end

    test "requires_approval status is returned when no approver is supplied" do
      result = AuthorizeAction.call(
        store: @store, requester: @clerk, permission_key: "pos.discount.apply", action_type: "discount_apply",
        limit_key: :maximum_discount_amount_cents, requested_value: 100
      )

      refute result.allowed?
      assert_equal :requires_approval, result.status
    end

    test "an approver must be a different user than the requester" do
      result = AuthorizeAction.call(
        store: @store, requester: @admin, permission_key: "pos.discount.apply", action_type: "discount_apply",
        limit_key: :maximum_discount_amount_cents, requested_value: 6000,
        approver: @admin, approver_pin: "1234"
      )

      refute result.allowed?
      assert_equal :denied, result.status
      assert_match(/self-approval is not permitted|differ/, result.error)
    end

    test "an approver authenticates with their own PIN, not the requester's" do
      result = AuthorizeAction.call(
        store: @store, requester: @clerk, permission_key: "pos.discount.apply", action_type: "discount_apply",
        limit_key: :maximum_discount_amount_cents, requested_value: 100,
        approver: @admin, approver_pin: "wrong-pin"
      )

      refute result.allowed?
      assert_match(/credentials/, result.error)
    end

    test "a valid independent approver with sufficient permission and authority creates a PosApproval" do
      result = AuthorizeAction.call(
        store: @store, requester: @clerk, permission_key: "pos.discount.apply", action_type: "discount_apply",
        reason: "manager approved", limit_key: :maximum_discount_amount_cents, requested_value: 100,
        approver: @admin, approver_pin: "1234"
      )

      assert result.allowed?
      assert_equal :approved, result.status
      approval = result.pos_approval
      assert approval.persisted?
      assert_equal @clerk, approval.requested_by_user
      assert_equal @admin, approval.approved_by_user
      assert_equal "discount_apply", approval.action_type
      assert_equal "manager approved", approval.reason
      assert_equal 100, approval.requested_value.to_i
      assert_equal 5000, approval.authorization_limit_snapshot.to_i
    end

    test "an approver lacking the required permission is denied even with correct credentials" do
      result = AuthorizeAction.call(
        store: @store, requester: @clerk, permission_key: "pos.discount.apply", action_type: "discount_apply",
        approver_permission_key: "pos.discount.approve", limit_key: :maximum_discount_amount_cents,
        requested_value: 100, approver: @catalog_editor, approver_pin: "5678"
      )

      refute result.allowed?
      assert_match(/lacks pos\.discount\.approve/, result.error)
    end

    test "an approver whose own authority also falls short is denied" do
      result = AuthorizeAction.call(
        store: @store, requester: @clerk, permission_key: "pos.discount.apply", action_type: "discount_apply",
        limit_key: :maximum_discount_amount_cents, requested_value: 100_000,
        approver: @admin, approver_pin: "1234"
      )

      refute result.allowed?
      assert_match(/authority is also insufficient/, result.error)
    end

    test "missing requester permission cannot be bypassed by a valid approver" do
      result = AuthorizeAction.call(
        store: @store, requester: @catalog_editor, permission_key: "pos.price.override",
        action_type: "price_override", reason: "manager cover",
        limit_key: :maximum_price_override_rate, requested_value: 0.1,
        approver: @admin, approver_pin: "1234"
      )

      refute result.allowed?
      assert_equal :denied, result.status
      assert_match(/missing permission pos\.price\.override/, result.error)
      assert_nil result.pos_approval
    end
  end
end
