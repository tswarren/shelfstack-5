# frozen_string_literal: true

require "test_helper"

module StoredValue
  class CreateAccountCredentialCollisionTest < ActiveSupport::TestCase
    setup do
      @org = organizations(:acme)
      @admin = users(:admin)
      IdentifierSequence.ensure_defaults!
    end

    test "rejects alternate identifier that matches another account number" do
      first = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin
      ).account

      denied = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin,
        alternate_identifier: first.account_number
      )
      refute denied.success?
      assert_match(/already used|account number/, denied.error)
    end

    test "generation skips candidates occupied as alternate identifiers" do
      occupant = CreateAccount.call(
        organization: @org, account_type: "store_credit", actor: @admin
      ).account

      sequence = IdentifierSequence.find("21")
      upcoming = compose_ean13("21", sequence.next_value)
      # Phase 6: alternate_identifier is immutable via Active Record; plant an
      # occupied credential with SQL for generation-skip coverage.
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        UPDATE stored_value_accounts
        SET alternate_identifier = #{ActiveRecord::Base.connection.quote(upcoming)}
        WHERE id = #{occupant.id}
      SQL
      assert_equal upcoming, occupant.reload.alternate_identifier

      created = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin
      )
      assert created.success?, created.error
      refute_equal upcoming, created.account.account_number
    end

    test "rejects account number that matches another alternate identifier via model validation" do
      first = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin,
        alternate_identifier: "preprintcollision1"
      ).account
      assert_equal "preprintcollision1", first.alternate_identifier

      colliding = StoredValueAccount.new(
        organization: @org,
        account_type: "gift_card",
        account_number: first.alternate_identifier,
        status: "active",
        current_balance_cents: 0,
        created_by_user: @admin
      )
      refute colliding.valid?
      assert_match(/alternate identifier/, colliding.errors[:account_number].join)
    end

    test "rejects alternate identifier equal to own account number" do
      number = compose_ean13("21", 9_876_543_210)
      twin = StoredValueAccount.new(
        organization: @org,
        account_type: "gift_card",
        account_number: number,
        alternate_identifier: number,
        status: "active",
        current_balance_cents: 0,
        created_by_user: @admin
      )
      refute twin.valid?
      assert_match(/cannot equal|account number/, twin.errors[:alternate_identifier].join)
    end

    test "alternate_identifier is immutable after create" do
      account = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin,
        alternate_identifier: "immutable-alt-1"
      ).account
      assert_equal "immutablealt1", account.alternate_identifier
      assert_raises(ActiveRecord::ReadonlyAttributeError) do
        account.update(alternate_identifier: "changed-alt")
      end
      assert_equal "immutablealt1", account.reload.alternate_identifier
    end

    test "alternate uniqueness index is organization scoped" do
      index = ActiveRecord::Base.connection.indexes(:stored_value_accounts).find { |i|
        i.columns == %w[organization_id alternate_identifier]
      }
      assert index, "expected unique index on organization_id + alternate_identifier"
      assert index.unique
      assert_match(/alternate_identifier IS NOT NULL/, index.where.to_s)
    end

    private

    def compose_ean13(namespace, payload)
      twelve = "#{namespace}#{payload.to_s.rjust(10, '0')}"
      sum = twelve.chars.each_with_index.sum { |ch, i| i.even? ? ch.to_i : ch.to_i * 3 }
      "#{twelve}#{(10 - (sum % 10)) % 10}"
    end
  end
end
