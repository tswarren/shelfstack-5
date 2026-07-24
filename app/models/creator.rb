# frozen_string_literal: true

# Organization-owned bibliographic Creator master (OD-P8-02). Duplicate
# Creators and duplicate normalized names are acceptable in v1 -- name
# matching is advisory only; ShelfStack never merges Creators automatically.
class Creator < ApplicationRecord
  belongs_to :organization
  has_many :product_creators, dependent: :restrict_with_exception
  has_many :products, through: :product_creators

  before_validation :set_normalized_name
  before_validation :default_sort_name

  validates :display_name, presence: true
  validates :normalized_name, presence: true
  validates :sort_name, presence: true
  validates :active, inclusion: { in: [ true, false ] }

  private

  def set_normalized_name
    self.normalized_name = Catalog::NormalizeCreatorName.call(display_name)
  end

  # No inverted "Last, First" guessing -- default sort_name to display_name.
  def default_sort_name
    self.sort_name = display_name if sort_name.blank?
  end
end
