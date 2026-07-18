# frozen_string_literal: true

class AdministrativeAuditEvent < ApplicationRecord
  belongs_to :actor_user, class_name: "User"
  belongs_to :organization
  belongs_to :store, optional: true

  validates :action, presence: true
  validates :subject_type, presence: true
  validates :subject_id, presence: true

  before_destroy :prevent_destruction

  def readonly?
    !new_record?
  end

  private

  def prevent_destruction
    raise ActiveRecord::ReadOnlyRecord, "administrative audit events are append-only"
  end
end
