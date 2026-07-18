# frozen_string_literal: true

module Classification
  class UpdateStoreTaxRule < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      tax_category_id store_tax_rate_id component_code treatment taxable_fraction
      calculation_order compounds_on_prior_tax effective_from effective_to active
    ].freeze

    def initialize(store_tax_rule:, attributes:, actor:, organization:, store:)
      @store_tax_rule = store_tax_rule
      @attributes = attributes.stringify_keys
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@store_tax_rule, TRACKED_ATTRIBUTES)

        @store_tax_rule.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @store_tax_rule.save!

        metadata = {
          "component_code" => @store_tax_rule.component_code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@store_tax_rule, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "store_tax_rule.updated",
          subject: @store_tax_rule,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
