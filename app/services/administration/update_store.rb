# frozen_string_literal: true

module Administration
  class UpdateStore < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      code store_number name legal_name timezone currency_code active
    ].freeze

    def initialize(store:, attributes:, actor:, organization:)
      @store = store
      @attributes = attributes
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = ChangeMetadata.snapshot(@store, TRACKED_ATTRIBUTES)

        @store.assign_attributes(@attributes)
        @store.save!

        metadata = {
          "code" => @store.code
        }.merge(ChangeMetadata.diff(before, ChangeMetadata.snapshot(@store, TRACKED_ATTRIBUTES)))

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "store.updated",
          subject: @store,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
