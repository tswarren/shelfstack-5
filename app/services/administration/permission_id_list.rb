# frozen_string_literal: true

module Administration
  # Strictly parses submitted permission IDs. Rejects nonnumeric, blank, and non-positive values.
  module PermissionIdList
    module_function

    def resolve!(raw_ids, error_target:)
      selected_ids = Array(raw_ids).map { |value| parse_id(value) }

      if selected_ids.any? { |id| id.nil? || id <= 0 }
        error_target.errors.add(:base, "One or more permission IDs are invalid")
        raise ActiveRecord::RecordInvalid, error_target
      end

      selected_ids = selected_ids.uniq
      permissions = Permission.where(id: selected_ids).to_a
      if permissions.size != selected_ids.size
        error_target.errors.add(:base, "One or more permission IDs are invalid")
        raise ActiveRecord::RecordInvalid, error_target
      end

      permissions
    end

    def parse_id(value)
      return nil if value.nil?

      string = value.to_s.strip
      return nil if string.empty?

      Integer(string, exception: false)
    end
  end
end
