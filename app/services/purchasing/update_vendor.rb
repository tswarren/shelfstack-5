# frozen_string_literal: true

module Purchasing
  class UpdateVendor < ApplicationService
    TRACKED_ATTRIBUTES = CreateVendor::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(vendor:, attributes:, actor:, organization:, store: nil)
      @vendor = vendor
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      if @store.blank?
        @vendor.errors.add(:base, "store is required to authorize vendor management")
        return false
      end
      if Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "purchasing.vendor.manage") != :allow
        @vendor.errors.add(:base, "not permitted to manage vendors")
        return false
      end

      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@vendor, TRACKED_ATTRIBUTES)

        @vendor.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @vendor.save!

        metadata = {
          "code" => @vendor.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@vendor, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "vendor.updated",
          subject: @vendor,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
