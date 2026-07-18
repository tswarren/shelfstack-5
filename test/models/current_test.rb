# frozen_string_literal: true

require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup { Current.reset }

  teardown { Current.reset }

  test "assigns user, organization, and store" do
    user = Object.new
    organization = Object.new
    store = Object.new

    Current.user = user
    Current.organization = organization
    Current.store = store

    assert_same user, Current.user
    assert_same organization, Current.organization
    assert_same store, Current.store
  end

  test "reset clears all attributes" do
    Current.user = Object.new
    Current.organization = Object.new
    Current.store = Object.new

    Current.reset

    assert_nil Current.user
    assert_nil Current.organization
    assert_nil Current.store
  end
end
