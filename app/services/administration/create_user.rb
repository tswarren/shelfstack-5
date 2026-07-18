# frozen_string_literal: true

module Administration
  class CreateUser < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      username user_number first_name last_name email default_store_id active
    ].freeze

    def initialize(user:, actor:, organization:, store:)
      @user = user
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @user.password_changed_at ||= Time.current if @user.password.present?
        @user.save!

        metadata = {
          "username" => @user.username,
          "after" => ChangeMetadata.snapshot(@user, TRACKED_ATTRIBUTES)
        }
        metadata["password_changed"] = true if @user.password.present?

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "user.created",
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
