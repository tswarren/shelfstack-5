# frozen_string_literal: true

require "test_helper"

module StoredValue
  class ResolveAccountTest < ActiveSupport::TestCase
    setup do
      @org = organizations(:acme)
      @admin = users(:admin)
      IdentifierSequence.ensure_defaults!
      @account = CreateAccount.call(
        organization: @org, account_type: "gift_card", actor: @admin,
        alternate_identifier: "PREPRINT-#{SecureRandom.hex(3)}"
      ).account
    end

    test "resolves by account number and alternate identifier" do
      by_number = ResolveAccount.call(organization: @org, identifier: @account.account_number)
      assert_equal @account.id, by_number.account.id
      assert_equal "account_number", by_number.matched_on

      by_alt = ResolveAccount.call(organization: @org, identifier: @account.alternate_identifier)
      assert_equal @account.id, by_alt.account.id
      assert_equal "alternate_identifier", by_alt.matched_on
    end

    test "not found raises" do
      assert_raises(ResolveAccount::NotFoundError) do
        ResolveAccount.call(organization: @org, identifier: "0000000000000")
      end
    end
  end
end
