# frozen_string_literal: true

require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "belongs to organization and requires code name timezone currency" do
    store = Store.new(organization: organizations(:acme))
    assert_not store.valid?
    assert_includes store.errors[:code], "can't be blank"
    assert_includes store.errors[:name], "can't be blank"
    assert_includes store.errors[:timezone], "can't be blank"
    assert_includes store.errors[:currency_code], "can't be blank"
  end

  test "enforces unique code within organization" do
    duplicate = stores(:main_street).dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "rejects unrecognized timezone" do
    store = stores(:main_street)
    store.timezone = "Not/A_Zone"
    assert_not store.valid?
    assert_includes store.errors[:timezone], "is not a recognized time zone"
  end

  test "defaults card reconciliation grain to business_day" do
    store = stores(:main_street)
    assert_equal "business_day", store.card_reconciliation_grain
    assert_equal 1, store.next_session_z_number
    assert_equal 1, store.next_business_day_z_number
  end

  test "rejects invalid card reconciliation grain" do
    store = stores(:main_street)
    store.card_reconciliation_grain = "terminal_batch"
    assert_not store.valid?
    assert_includes store.errors[:card_reconciliation_grain], "is not included in the list"
  end

  test "rejects selecting session card grain while not yet operable" do
    store = stores(:main_street)
    store.card_reconciliation_grain = "session"
    assert_not store.valid?
    assert_match(/not available/, store.errors[:card_reconciliation_grain].join)
  end

  test "allows remediating legacy session grain back to business_day" do
    store = stores(:main_street)
    store.update_columns(card_reconciliation_grain: "session")
    store.reload
    store.name = "#{store.name} updated"
    assert store.valid?, store.errors.full_messages.join(", ")
    store.card_reconciliation_grain = "business_day"
    assert store.valid?, store.errors.full_messages.join(", ")
    assert store.save
  end

  test "requires positive z number sequences" do
    store = stores(:main_street)
    store.next_session_z_number = 0
    assert_not store.valid?
    assert_includes store.errors[:next_session_z_number], "must be greater than or equal to 1"

    store = stores(:main_street)
    store.next_business_day_z_number = 0
    assert_not store.valid?
    assert_includes store.errors[:next_business_day_z_number], "must be greater than or equal to 1"
  end
end
