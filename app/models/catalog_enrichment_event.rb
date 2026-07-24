# frozen_string_literal: true

# Append-only catalog import-provenance event (OD-P8-09, phase-08 §8). Gate 8b
# ships the table, model, and immutability guarantee only -- events are
# written starting in 8c/8f, only when external metadata successfully
# applies. Ordinary manual Product/Creator edits never create these; they
# create ordinary AdministrativeAuditEvent evidence instead.
class CatalogEnrichmentEvent < ApplicationRecord
  ACTIONS = %w[create fill_empty selected_apply].freeze
  PROVIDERS = %w[isbndb google_books].freeze

  belongs_to :product
  belongs_to :organization
  belongs_to :actor_user, class_name: "User"

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :requested_identifier, presence: true
  validates :canonical_identifier, presence: true
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :retrieved_at, presence: true
  validate :product_belongs_to_organization

  before_destroy :prevent_destruction

  def readonly?
    !new_record?
  end

  private

  def product_belongs_to_organization
    return if product.blank? || organization.blank?

    if product.organization_id != organization_id
      errors.add(:product, "must belong to the same organization as the enrichment event")
    end
  end

  def prevent_destruction
    raise ActiveRecord::ReadOnlyRecord, "catalog enrichment events are append-only"
  end
end
