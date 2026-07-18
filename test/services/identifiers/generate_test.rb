# frozen_string_literal: true

require "test_helper"

class IdentifiersGenerateTest < ActiveSupport::TestCase
  setup do
    IdentifierSequence.ensure_defaults!
  end

  test "generates valid EAN-13 in namespace 28" do
    value = Identifiers::Generate.call(namespace: "28")

    assert_match(/\A28\d{11}\z/, value)
    normalized = Identifiers::Normalize.call(value)
    assert_equal :valid, normalized.validation_status
    assert_equal :generated_28, normalized.type
  end

  test "raises when sequence would exceed ten-digit payload" do
    IdentifierSequence.find("29").update!(next_value: 10_000_000_000)

    assert_raises(Identifiers::Generate::SequenceOverflowError) do
      Identifiers::Generate.call(namespace: "29")
    end
  end

  test "skips candidates already present when occupied callback is provided" do
    IdentifierSequence.find("29").update!(next_value: 1)
    first = Identifiers::Generate.call(namespace: "29")
    IdentifierSequence.find("29").update!(next_value: 1)

    occupied = Set.new([ first ])
    second = Identifiers::Generate.call(
      namespace: "29",
      occupied: ->(candidate) { occupied.include?(candidate) }
    )

    assert_not_equal first, second
    assert_equal 3, IdentifierSequence.find("29").next_value
  end

  test "concurrent generation produces distinct identifiers" do
    IdentifierSequence.find("28").update!(next_value: 100)

    values = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          values << Identifiers::Generate.call(namespace: "28")
        end
      end
    end
    threads.each(&:join)

    generated = 2.times.map { values.pop }
    assert_equal 2, generated.uniq.length
    generated.each do |value|
      assert Identifiers::Normalize.call(value).validation_status == :valid
    end
  end
end
