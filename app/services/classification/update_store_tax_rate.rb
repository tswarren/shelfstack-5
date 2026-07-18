# frozen_string_literal: true

module Classification
  class UpdateStoreTaxRate < ApplicationService
    TRACKED_ATTRIBUTES = %w[code name receipt_code jurisdiction_name rate effective_from effective_to active].freeze
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(store_tax_rate:, attributes:, actor:, organization:, store:)
      @store_tax_rate = store_tax_rate
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@store_tax_rate, TRACKED_ATTRIBUTES)

        @store_tax_rate.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @store_tax_rate.save!

        metadata = {
          "code" => @store_tax_rate.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@store_tax_rate, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "store_tax_rate.updated",
          subject: @store_tax_rate,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
