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
      occupant.update!(alternate_identifier: upcoming)
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

    private

    def compose_ean13(namespace, payload)
      twelve = "#{namespace}#{payload.to_s.rjust(10, '0')}"
      sum = twelve.chars.each_with_index.sum { |ch, i| i.even? ? ch.to_i : ch.to_i * 3 }
      "#{twelve}#{(10 - (sum % 10)) % 10}"
    end
  end
end
