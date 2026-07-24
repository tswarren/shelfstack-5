# frozen_string_literal: true

module Catalog
  # Atomic Product-Creator link replacement (phase-08 §7, §4 of the Gate 8b
  # plan). Must run inside the caller's existing Product transaction --
  # never after it commits.
  #
  # Omission vs clear vs replace (never treat nil and [] as equivalent):
  #
  #   OMIT / nil -> preserve existing ProductCreator rows
  #   []         -> intentionally remove all ProductCreator rows
  #   [...]      -> atomically replace the complete ordered collection
  #
  # Positions are service-authoritative: submitted position values are
  # ignored. Contiguous zero-based positions are derived from array order.
  class ReplaceProductCreators < ApplicationService
    OMIT = :"catalog/replace_product_creators/omit"

    def initialize(product:, assignments:, actor:, store:)
      @product = product
      @assignments = assignments
      @actor = actor
      @store = store
    end

    def call
      return true if omitted?

      unless @assignments.is_a?(Array)
        @product.errors.add(:creator_assignments, "must be an array")
        return false
      end

      before_snapshot = snapshot
      resolved = build_resolved_assignments
      return false if @product.errors[:creator_assignments].any?
      return false unless validate_prospective!(resolved)

      replace!(resolved)
      audit_link_changes!(before_snapshot)
      true
    end

    private

    def omitted?
      @assignments == OMIT || @assignments.nil?
    end

    def build_resolved_assignments
      seen = {}
      resolved = []

      @assignments.each do |raw|
        hash = raw.respond_to?(:to_h) ? raw.to_h.symbolize_keys : {}
        creator_id = hash[:creator_id]
        role = hash[:role].to_s
        credited_as = hash[:credited_as].to_s.strip.presence

        if creator_id.blank?
          @product.errors.add(:creator_assignments, "creator is required")
          next
        end

        unless ProductCreator::ROLES.include?(role)
          @product.errors.add(:creator_assignments, "role must be one of #{ProductCreator::ROLES.join(', ')}")
          next
        end

        # Scoped to the product's own organization: a foreign-organization
        # creator id resolves to nil, and we never disclose its name.
        creator = @product.organization.creators.find_by(id: creator_id)
        if creator.nil?
          @product.errors.add(:creator_assignments, "creator could not be found")
          next
        end

        key = [ creator.id, role ]
        if seen[key]
          @product.errors.add(:creator_assignments, "creator is already assigned with the same role")
          next
        end
        seen[key] = true

        resolved << { creator: creator, role: role, credited_as: credited_as }
      end

      resolved
    end

    # Validate join attributes before destroy_all so a failed create! cannot
    # leave the product with an empty creator set. Soft uniqueness against
    # rows that will be replaced is already handled in build_resolved_assignments;
    # skip that callback here by checking only attribute validations that
    # would still fail after the replace.
    def validate_prospective!(resolved)
      valid = true
      resolved.each_with_index do |attrs, index|
        record = ProductCreator.new(
          product: @product,
          creator: attrs[:creator],
          role: attrs[:role],
          credited_as: attrs[:credited_as],
          position: index
        )
        record.validate
        blocking_messages = record.errors.map do |error|
          next if error.attribute == :creator_id && error.message.include?("already linked")

          error.full_message
        end.compact
        next if blocking_messages.empty?

        valid = false
        blocking_messages.each { |message| @product.errors.add(:creator_assignments, message) }
      end
      valid
    end

    def replace!(resolved)
      @product.product_creators.destroy_all
      resolved.each_with_index do |attrs, index|
        @product.product_creators.create!(
          creator: attrs[:creator],
          role: attrs[:role],
          credited_as: attrs[:credited_as],
          position: index
        )
      end
    end

    def snapshot
      @product.product_creators.order(:position, :id).map do |pc|
        { "creator_id" => pc.creator_id, "role" => pc.role, "credited_as" => pc.credited_as, "position" => pc.position }
      end
    end

    def audit_link_changes!(before_snapshot)
      after_snapshot = @product.product_creators.reload.order(:position, :id).map do |pc|
        { "creator_id" => pc.creator_id, "role" => pc.role, "credited_as" => pc.credited_as, "position" => pc.position }
      end
      return if before_snapshot == after_snapshot

      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: @product.organization,
        store: @store,
        action: "catalog.product.creators_replaced",
        subject: @product,
        metadata: { "before" => before_snapshot, "after" => after_snapshot }
      )
    end
  end
end
