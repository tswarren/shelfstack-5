# frozen_string_literal: true

module Administration
  class UpdateCashDrawer < ApplicationService
    TRACKED_ATTRIBUTES = %w[code name active].freeze

    def initialize(drawer:, attributes:, actor:, organization:, store:)
      @drawer = drawer
      @attributes = attributes
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        before = ChangeMetadata.snapshot(@drawer, TRACKED_ATTRIBUTES)

        @drawer.assign_attributes(@attributes)
        @drawer.save!

        metadata = {
          "code" => @drawer.code
        }.merge(ChangeMetadata.diff(before, ChangeMetadata.snapshot(@drawer, TRACKED_ATTRIBUTES)))

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "drawer.updated",
          subject: @drawer,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
