# frozen_string_literal: true

module Administration
  class UpdatePosDevice < ApplicationService
    TRACKED_ATTRIBUTES = %w[code name device_type active].freeze

    def initialize(device:, attributes:, actor:, organization:, store:)
      @device = device
      @attributes = attributes
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        before = ChangeMetadata.snapshot(@device, TRACKED_ATTRIBUTES)

        @device.assign_attributes(@attributes)
        @device.save!

        metadata = {
          "code" => @device.code
        }.merge(ChangeMetadata.diff(before, ChangeMetadata.snapshot(@device, TRACKED_ATTRIBUTES)))

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "device.updated",
          subject: @device,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
