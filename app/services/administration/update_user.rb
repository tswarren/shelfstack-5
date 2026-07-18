# frozen_string_literal: true

module Administration
  class UpdateUser < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      username user_number first_name last_name email default_store_id active
    ].freeze

    def initialize(user:, attributes:, actor:, organization:, store:)
      @user = user
      @attributes = attributes
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        before = ChangeMetadata.snapshot(@user, TRACKED_ATTRIBUTES)

        @user.assign_attributes(@attributes)
        @user.save!

        metadata = {
          "username" => @user.username
        }.merge(ChangeMetadata.diff(before, ChangeMetadata.snapshot(@user, TRACKED_ATTRIBUTES)))

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "user.updated",
          subject: @user,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
