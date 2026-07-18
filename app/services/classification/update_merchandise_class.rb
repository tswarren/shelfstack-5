# frozen_string_literal: true

module Classification
  class UpdateMerchandiseClass < ApplicationService
    TRACKED_ATTRIBUTES = CreateMerchandiseClass::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(merchandise_class:, attributes:, actor:, organization:)
      @merchandise_class = merchandise_class
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@merchandise_class, TRACKED_ATTRIBUTES)

        @merchandise_class.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @merchandise_class.save!

        metadata = {
          "code" => @merchandise_class.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@merchandise_class, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "merchandise_class.updated",
          subject: @merchandise_class,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
