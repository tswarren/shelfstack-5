# frozen_string_literal: true

module Administration
  class RecordAuditEvent < ApplicationService
    def initialize(actor:, organization:, action:, subject:, store: nil, metadata: {})
      @actor = actor
      @organization = organization
      @action = action
      @subject = subject
      @store = store
      @metadata = metadata
    end

    def call
      AdministrativeAuditEvent.create!(
        actor_user: @actor,
        organization: @organization,
        store: @store,
        action: @action,
        subject_type: @subject.class.name,
        subject_id: @subject.id,
        metadata: @metadata,
        created_at: Time.current
      )
    end
  end
end
