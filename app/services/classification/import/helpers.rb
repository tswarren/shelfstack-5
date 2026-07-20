# frozen_string_literal: true

module Classification
  module Import
    module Helpers
      module_function

      def truthy?(value)
        value.to_s.strip.upcase == "TRUE"
      end

      def blank_value?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def assign_active_preserving_deactivation(record, csv_value)
        desired_active = if blank_value?(csv_value)
          true
        else
          truthy?(csv_value)
        end

        if record.new_record?
          record.active = desired_active
        elsif record.active == false
          record.active = false
        else
          record.active = desired_active
        end
      end

      def load_csv(relative_path)
        path = Rails.root.join("docs/exports", relative_path)
        CSV.read(path, headers: true)
      end
    end
  end
end
