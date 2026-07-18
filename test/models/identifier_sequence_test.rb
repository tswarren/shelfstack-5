# frozen_string_literal: true

require "test_helper"

class IdentifierSequenceTest < ActiveSupport::TestCase
  test "ensure_defaults creates all namespaces without resetting next_value" do
    IdentifierSequence.delete_all

    IdentifierSequence.ensure_defaults!
    assert_equal %w[21 27 28 29], IdentifierSequence.order(:namespace).pluck(:namespace)
    assert_equal [ 1, 1, 1, 1 ], IdentifierSequence.order(:namespace).pluck(:next_value)

    seq = IdentifierSequence.find("28")
    seq.update!(next_value: 42)

    IdentifierSequence.ensure_defaults!
    assert_equal 42, IdentifierSequence.find("28").next_value
  end

  test "rejects unknown namespace" do
    row = IdentifierSequence.new(namespace: "99", next_value: 1)
    assert_not row.valid?
    assert_includes row.errors[:namespace], "is not included in the list"
  end
end
