# frozen_string_literal: true

module Purchasing
  class UpdateVendor < ApplicationService
    TRACKED_ATTRIBUTES = CreateVendor::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(vendor:, attributes:, actor:, organization:)
      @vendor = vendor
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
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
