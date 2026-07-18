# frozen_string_literal: true

module TimezoneValidatable
  extend ActiveSupport::Concern

  class_methods do
    def validates_timezone(*attributes)
      validate do
        attributes.each do |attribute|
          value = public_send(attribute)
          next if value.blank?
          next if Time.find_zone(value)

          errors.add(attribute, "is not a recognized time zone")
        end
      end
    end
  end
end
