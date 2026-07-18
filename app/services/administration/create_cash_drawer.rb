# frozen_string_literal: true

module Administration
  class CreateCashDrawer < ApplicationService
    TRACKED_ATTRIBUTES = %w[code name active].freeze

    def initialize(drawer:, actor:, organization:, store:)
      @drawer = drawer
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @drawer.save!

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "drawer.created",
          subject: @drawer,
          metadata: {
            "code" => @drawer.code,
            "after" => ChangeMetadata.snapshot(@drawer, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
