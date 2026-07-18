# frozen_string_literal: true

# Installation-singleton counters for generated EAN-13 namespaces (OD-011).
# No organization_id: INV-ORG-001 makes installation == one organization.
class IdentifierSequence < ApplicationRecord
  self.primary_key = :namespace

  NAMESPACES = %w[21 27 28 29].freeze

  validates :namespace, presence: true, inclusion: { in: NAMESPACES }
  validates :next_value, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  def self.ensure_defaults!
    NAMESPACES.each do |namespace|
      find_or_create_by!(namespace: namespace) do |row|
        row.next_value = 1
      end
    end
  end
end
