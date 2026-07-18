# frozen_string_literal: true

module Administration
  class CreatePosDevice < ApplicationService
    TRACKED_ATTRIBUTES = %w[code name device_type active].freeze

    def initialize(device:, actor:, organization:, store:)
      @device = device
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @device.save!

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "device.created",
          subject: @device,
          metadata: {
            "code" => @device.code,
            "after" => ChangeMetadata.snapshot(@device, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
