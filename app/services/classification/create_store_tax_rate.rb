# frozen_string_literal: true

module Classification
  class CreateStoreTaxRate < ApplicationService
    TRACKED_ATTRIBUTES = %w[code name receipt_code jurisdiction_name rate effective_from effective_to active].freeze

    def initialize(store_tax_rate:, actor:, organization:, store:)
      @store_tax_rate = store_tax_rate
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @store_tax_rate.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "store_tax_rate.created",
          subject: @store_tax_rate,
          metadata: {
            "code" => @store_tax_rate.code,
            "after" => Administration::ChangeMetadata.snapshot(@store_tax_rate, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
