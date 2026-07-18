# frozen_string_literal: true

module Administration
  class CreateStore < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      code store_number name legal_name timezone currency_code active
    ].freeze

    def initialize(store:, actor:, organization:)
      @store = store
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @store.save!

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "store.created",
          subject: @store,
          metadata: {
            "code" => @store.code,
            "after" => ChangeMetadata.snapshot(@store, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
