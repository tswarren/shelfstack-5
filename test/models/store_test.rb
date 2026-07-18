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
end
