# frozen_string_literal: true

module Classification
  class CreateStoreTaxRule < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      tax_category_id store_tax_rate_id component_code treatment taxable_fraction
      calculation_order compounds_on_prior_tax effective_from effective_to active
    ].freeze

    def initialize(store_tax_rule:, actor:, organization:, store:)
      @store_tax_rule = store_tax_rule
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @store_tax_rule.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "store_tax_rule.created",
          subject: @store_tax_rule,
          metadata: {
            "component_code" => @store_tax_rule.component_code,
            "after" => Administration::ChangeMetadata.snapshot(@store_tax_rule, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
