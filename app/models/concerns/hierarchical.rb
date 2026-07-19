# frozen_string_literal: true

require "set"

# Shared parent-chain validations for organization-scoped hierarchies.
module Hierarchical
  extend ActiveSupport::Concern

  class_methods do
    def hierarchy_parent_association(association_name = nil)
      @hierarchy_parent_association = association_name if association_name
      @hierarchy_parent_association || :parent
    end

    # Depth-first order: each parent, then its children (siblings by position, name).
    def sorted_hierarchically(scope = all)
      records = scope.respond_to?(:to_a) ? scope.to_a : Array(scope)
      parent_fk = :"#{hierarchy_parent_association}_id"
      by_parent = records.group_by { |record| record.public_send(parent_fk) }
      sort_key = ->(record) {
        [ record.try(:position) || Float::INFINITY, record.name.to_s.downcase, record.id ]
      }

      ordered = []
      walk = lambda do |parent_id|
        (by_parent[parent_id] || []).sort_by(&sort_key).each do |record|
          ordered << record
          walk.call(record.id)
        end
      end
      walk.call(nil)

      # Keep records whose parent is outside the collection (orphaned subset).
      (records - ordered).sort_by(&sort_key).each { |record| ordered << record }
      ordered
    end
  end

  included do
    validate :parent_belongs_to_same_organization
    validate :cannot_be_own_parent
    validate :no_hierarchy_cycles
  end

  private

  def hierarchy_parent
    public_send(self.class.hierarchy_parent_association)
  end

  def hierarchy_parent_id
    public_send(:"#{self.class.hierarchy_parent_association}_id")
  end

  def parent_belongs_to_same_organization
    return if hierarchy_parent.blank?

    if hierarchy_parent.organization_id != organization_id
      errors.add(self.class.hierarchy_parent_association, "must belong to the same organization")
    end
  end

  def cannot_be_own_parent
    return if hierarchy_parent_id.blank? || id.blank?

    if hierarchy_parent_id == id
      errors.add(self.class.hierarchy_parent_association, "cannot be the record itself")
    end
  end

  def no_hierarchy_cycles
    return if hierarchy_parent_id.blank?

    visited_ids = Set.new([ id ].compact)
    current = hierarchy_parent

    while current
      if visited_ids.include?(current.id)
        errors.add(self.class.hierarchy_parent_association, "would create a hierarchy cycle")
        break
      end

      visited_ids.add(current.id)
      current = current.public_send(self.class.hierarchy_parent_association)
    end
  end
end
