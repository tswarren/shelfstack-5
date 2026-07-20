# frozen_string_literal: true

# Store-local calendar dates and wall-clock times.
# Timestamps are stored in UTC; display and date-only defaults use the store zone.
module StoreTime
  module_function

  def zone_for(store)
    name = store&.timezone.presence || Time.zone.name
    Time.find_zone!(name)
  end

  def now(store)
    zone_for(store).now
  end

  def today(store)
    zone_for(store).today
  end

  def at(store, moment)
    return nil if moment.blank?

    moment.in_time_zone(zone_for(store))
  end

  def parse_in_zone(store, value)
    return nil if value.blank?

    zone_for(store).parse(value.to_s)
  end
end
