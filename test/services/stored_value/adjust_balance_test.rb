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
        organization: @org, account_type: "gift_card", actor: @admin, store: @store
      ).account
      @reason = StoredValueAdjustmentReason.create!(
        organization: @org, code: "manual_fix", name: "Manual correction",
        requires_note: true, active: true, position: 1
      )

      admin_role = roles(:administrator)
      %w[
        stored_value.adjustment.create
        stored_value.adjustment.approve
        stored_value.adjustment.approve_self
      ].each do |code|
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

    test "self-approval with approve_self posts adjustment" do
      result = AdjustBalance.call(
        account: @account, store: @store, amount_cents: 100, adjustment_reason: @reason,
        actor: @admin, description: "note",
        approver: @admin, approver_pin: "1234",
        posting_key: "sv-adj-self"
      )
      assert result.success?, result.error
      assert_equal @admin.id, result.pos_approval.requested_by_user_id
      assert_equal @admin.id, result.pos_approval.approved_by_user_id
    end

    test "self-approval without approve_self is denied" do
      RolePermission.joins(:permission).where(
        role: roles(:administrator),
        permissions: { code: "stored_value.adjustment.approve_self" }
      ).delete_all

      result = AdjustBalance.call(
        account: @account, store: @store, amount_cents: 100, adjustment_reason: @reason,
        actor: @admin, description: "note",
        approver: @admin, approver_pin: "1234",
        posting_key: "sv-adj-self-denied"
      )
      refute result.success?
      assert_match(/approve_self/, result.error)
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

    test "same posting_key replays without a second entry" do
      first = AdjustBalance.call(
        account: @account, store: @store, amount_cents: 250, adjustment_reason: @reason,
        actor: @admin, description: "note",
        approver: @approver, approver_pin: "4321",
        posting_key: "sv-adj-idem"
      )
      assert first.success?, first.error

      second = AdjustBalance.call(
        account: @account, store: @store, amount_cents: 250, adjustment_reason: @reason,
        actor: @admin, description: "note",
        approver: @approver, approver_pin: "4321",
        posting_key: "sv-adj-idem"
      )
      assert second.success?, second.error
      assert second.replayed
      assert_equal first.entry.id, second.entry.id
      assert_equal 250, @account.reload.current_balance_cents
      assert_equal 1, StoredValueEntry.where(posting_key: "sv-adj-idem").count
    end

    test "concurrent same posting_key creates one entry and one approval" do
      results = {}
      barrier = Concurrent::CyclicBarrier.new(2)
      t1 = Thread.new do
        barrier.wait
        results[:a] = AdjustBalance.call(
          account: @account, store: @store, amount_cents: 300, adjustment_reason: @reason,
          actor: @admin, description: "note",
          approver: @approver, approver_pin: "4321",
          posting_key: "sv-adj-race"
        )
      end
      t2 = Thread.new do
        barrier.wait
        results[:b] = AdjustBalance.call(
          account: @account, store: @store, amount_cents: 300, adjustment_reason: @reason,
          actor: @admin, description: "note",
          approver: @approver, approver_pin: "4321",
          posting_key: "sv-adj-race"
        )
      end
      [ t1, t2 ].each(&:join)

      assert results.values.all?(&:success?), results.values.map(&:error).inspect
      assert_equal 1, StoredValueEntry.where(posting_key: "sv-adj-race").count
      assert_equal 1, results.values.count { |r| !r.replayed }
      assert_equal 300, @account.reload.current_balance_cents
      approval_ids = results.values.map { |r| r.pos_approval&.id }.compact.uniq
      assert_equal 1, approval_ids.size
    end

    test "failed posting rolls back approval" do
      approvals_before = PosApproval.count
      original = PostEntry.method(:call)
      PostEntry.define_singleton_method(:call) do |**|
        raise PostEntry::Error, "injected failure"
      end

      begin
        result = AdjustBalance.call(
          account: @account, store: @store, amount_cents: 100, adjustment_reason: @reason,
          actor: @admin, description: "note",
          approver: @approver, approver_pin: "4321",
          posting_key: "sv-adj-fail"
        )
        refute result.success?
        assert_match(/injected failure/, result.error)
      ensure
        PostEntry.define_singleton_method(:call, original)
      end

      assert_equal 0, @account.reload.current_balance_cents
      refute StoredValueEntry.exists?(posting_key: "sv-adj-fail")
      assert_equal approvals_before, PosApproval.count
    end
  end
end
