# frozen_string_literal: true

class PosSessionZReport < ApplicationRecord
  belongs_to :pos_session
  belongs_to :store
  belongs_to :generated_by_user, class_name: "User"

  validates :z_number, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :business_date, :source_cutoff_at, :report_definition_version, :generated_at, :payload, presence: true
  validates :pos_session_id, uniqueness: true
  validates :z_number, uniqueness: { scope: :store_id }

  before_destroy :prevent_destroy
  before_update :prevent_mutation

  private

  def prevent_destroy
    raise ActiveRecord::ReadOnlyRecord, "session Z reports are immutable"
  end

  def prevent_mutation
    raise ActiveRecord::ReadOnlyRecord, "session Z reports are immutable"
  end
end
