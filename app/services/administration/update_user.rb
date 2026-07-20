# frozen_string_literal: true

module Administration
  class UpdateUser < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      username user_number first_name last_name email default_store_id active
    ].freeze

    def initialize(user:, attributes:, actor:, organization:, store:)
      @user = user
      @attributes = attributes.stringify_keys
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        before = ChangeMetadata.snapshot(@user, TRACKED_ATTRIBUTES)
        password_changing = password_present?
        pin_changing = pin_present?
        had_pin = @user.pin_digest.present?

        @user.assign_attributes(@attributes)
        @user.password_changed_at = Time.current if password_changing
        @user.pin_changed_at = Time.current if pin_changing
        @user.save!

        metadata = {
          "username" => @user.username
        }.merge(ChangeMetadata.diff(before, ChangeMetadata.snapshot(@user, TRACKED_ATTRIBUTES)))
        metadata["password_changed"] = true if password_changing
        if pin_changing
          metadata["pin_changed"] = true
          metadata["pin_action"] = had_pin ? "reset" : "set"
        end

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

    private

    def password_present?
      @attributes["password"].present?
    end

    def pin_present?
      @attributes["pin"].present?
    end
  end
end
