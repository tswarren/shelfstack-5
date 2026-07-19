# frozen_string_literal: true

require "test_helper"

class StoreTimeTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @store.update!(timezone: "America/New_York")
  end

  test "today uses the store time zone not UTC Date.current near midnight" do
    # 2026-03-15 02:30 UTC is still 2026-03-14 in America/New_York (EDT starts later in March).
    travel_to Time.utc(2026, 3, 15, 2, 30, 0) do
      assert_equal Date.new(2026, 3, 14), StoreTime.today(@store)
      refute_equal Date.current, StoreTime.today(@store) if Date.current != Date.new(2026, 3, 14)
    end
  end

  test "at converts a UTC timestamp into the store zone" do
    utc = Time.utc(2026, 7, 4, 4, 0, 0) # 00:00 EDT
    local = StoreTime.at(@store, utc)
    assert_equal "America/New_York", local.time_zone.name
    assert_equal 0, local.hour
  end

  test "DST spring forward keeps store-local calendar date stable" do
    # 2026-03-08 2:00 AM does not exist in America/New_York; 07:30 UTC is 02:30 EST before jump,
    # 08:30 UTC is 04:30 EDT after jump — both still March 8 locally.
    travel_to Time.utc(2026, 3, 8, 7, 30, 0) do
      assert_equal Date.new(2026, 3, 8), StoreTime.today(@store)
    end
    travel_to Time.utc(2026, 3, 8, 8, 30, 0) do
      assert_equal Date.new(2026, 3, 8), StoreTime.today(@store)
    end
  end

  test "OpenBusinessDay default reporting date matches store-local today" do
    travel_to Time.utc(2026, 3, 15, 2, 30, 0) do
      BusinessDay.where(store_id: @store.id, status: "open").find_each do |day|
        day.update!(status: "closed", closed_at: Time.current)
      end

      result = Pos::OpenBusinessDay.call(store: @store, actor: users(:admin))
      assert result.success?, result.error
      assert_equal Date.new(2026, 3, 14), result.business_day.reporting_date
    end
  end
end
