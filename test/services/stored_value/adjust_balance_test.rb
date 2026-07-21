# frozen_string_literal: true

require "test_helper"

module StoredValue
  class AdjustBalanceTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @org = @store.organization
      IdentifierSequence.ensure_defaults!
      @account = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin
      ).account
      @reason = StoredValueAdjustmentReason.create!(
        organization: @org, code: "manual_fix", name: "Manual correction",
        requires_note: true, active: true, position: 1
      )

      admin_role = roles(:administrator)
      %w[stored_value.adjustment.create stored_value.adjustment.approve].each do |code|
        perm = Permission.find_or_create_by!(code: code) do |p|
          p.name = code
          p.permission_group = "stored_value"
          p.active = true
        end
        RolePermission.find_or_create_by!(role: admin_role, permission: perm)
      end

      @approver = User.create!(
        username: "sv_approver",
        user_number: 9_001,
        first_name: "Sam",
        last_name: "Approver",
        password: "password123",
        pin: "4321",
        pin_confirmation: "4321",
        active: true,
        default_store: @store
      )
      StoreMembership.create!(user: @approver, store: @store, role: admin_role, active: true)
    end

    test "independent approval posts adjustment" do
      result = AdjustBalance.call(
        account: @account, store: @store, amount_cents: 750, adjustment_reason: @reason,
        actor: @admin, description: "goodwill",
        approver: @approver, approver_pin: "4321",
        posting_key: "sv-adj-1"
      )

      assert result.success?, result.error
      assert_equal 750, @account.reload.current_balance_cents
      assert_equal "manual_adjustment", result.entry.entry_type
      assert_equal "stored_value_adjustment", result.pos_approval.action_type
    end

    test "self-approval is denied for adjustments" do
      result = AdjustBalance.call(
        account: @account, store: @store, amount_cents: 100, adjustment_reason: @reason,
        actor: @admin, description: "note",
        approver: @admin, approver_pin: "1234",
        posting_key: "sv-adj-self"
      )
      refute result.success?
      assert_match(/differ from requester|approval/i, result.error)
    end

    test "missing note is rejected when reason requires it" do
      result = AdjustBalance.call(
        account: @account, store: @store, amount_cents: 100, adjustment_reason: @reason,
        actor: @admin, description: nil,
        approver: @approver, approver_pin: "4321",
        posting_key: "sv-adj-note"
      )
      refute result.success?
      assert_match(/description/i, result.error)
    end
  end
end
