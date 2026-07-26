# frozen_string_literal: true

# Organization-scoped Customer master (ADR-0017 / Phase 9).
# Canonical identity is an immutable generated namespace-22 EAN-13 customer_number.
# Phone store-country parsing belongs in Customers::* services, not here.
class Customer < ApplicationRecord
  CUSTOMER_TYPES = %w[individual organization].freeze
  PREFERRED_CONTACT_METHODS = %w[phone email none].freeze

  belongs_to :organization
  has_many :product_requests, dependent: :restrict_with_exception
  has_many :pos_transactions, dependent: :restrict_with_exception

  attr_readonly :customer_number

  before_validation :normalize_customer_data

  validates :customer_number, presence: true, uniqueness: true
  validates :customer_type, presence: true, inclusion: { in: CUSTOMER_TYPES }
  validates :preferred_contact_method, presence: true, inclusion: { in: PREFERRED_CONTACT_METHODS }
  validates :country_code, length: { is: 2 }, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }
  validate :customer_number_is_generated_22
  validate :type_specific_name_rules
  validate :preferred_contact_primary_fields
  validate :phones_are_e164_or_blank
  validate :emails_look_reasonable

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :for_organization, ->(organization) { where(organization_id: organization.id) }

  def display_name
    if customer_type == "organization"
      organization_name.to_s
    else
      [ first_name, last_name ].compact_blank.join(" ")
    end
  end

  # Search/picker label: identity plus phone, email, and city when present.
  # When +query+ matches an alternate contact, that value is preferred so the
  # cashier sees the term they typed.
  def picker_label(query: nil)
    [
      display_name.presence || "Customer",
      customer_number,
      contact_value_for_label(:phone, query),
      contact_value_for_label(:email, query),
      city.presence
    ].compact.join(" · ")
  end

  def individual?
    customer_type == "individual"
  end

  def organization_customer?
    customer_type == "organization"
  end

  def contactable?
    case preferred_contact_method
    when "phone" then primary_phone.present?
    when "email" then primary_email.present?
    else false
    end
  end

  private

  def contact_value_for_label(kind, query)
    primary, alternate = case kind
    when :phone then [ primary_phone, alternate_phone ]
    when :email then [ primary_email, alternate_email ]
    else return nil
    end

    q = query.to_s.strip
    if q.present?
      if contact_matches_query?(alternate, q, kind)
        return alternate
      end
      if contact_matches_query?(primary, q, kind)
        return primary
      end
    end

    primary.presence || alternate.presence
  end

  def contact_matches_query?(value, query, kind)
    return false if value.blank?

    if kind == :phone
      value_digits = value.gsub(/\D/, "")
      query_digits = query.gsub(/\D/, "")
      return true if query_digits.length >= 7 && value_digits.end_with?(query_digits)
      return true if value.include?(query)
    end

    value.to_s.downcase.include?(query.downcase)
  end

  def normalize_customer_data
    self.organization_name = organization_name.to_s.strip.presence
    self.first_name = first_name.to_s.strip.presence
    self.last_name = last_name.to_s.strip.presence
    self.address_line_1 = address_line_1.to_s.strip.presence
    self.address_line_2 = address_line_2.to_s.strip.presence
    self.city = city.to_s.strip.presence
    self.region = region.to_s.strip.presence
    self.postal_code = postal_code.to_s.strip.presence
    self.country_code = country_code.to_s.strip.upcase.presence
    self.notes = notes.to_s.strip.presence
    self.primary_email = normalize_email_value(primary_email)
    self.alternate_email = normalize_email_value(alternate_email)
    self.primary_phone = primary_phone.to_s.strip.presence
    self.alternate_phone = alternate_phone.to_s.strip.presence
  end

  def normalize_email_value(raw)
    return nil if raw.blank?

    raw.to_s.strip.downcase.presence
  end

  def customer_number_is_generated_22
    return if customer_number.blank?

    normalized = Identifiers::Normalize.call(customer_number)
    return if normalized.type == :generated_22 && normalized.validation_status == :valid

    errors.add(:customer_number, "must be a valid generated namespace 22 EAN-13")
  end

  def type_specific_name_rules
    if individual?
      if organization_name.present?
        errors.add(:organization_name, "must be blank for individual customers")
      end
      if first_name.blank? && last_name.blank?
        errors.add(:base, "individual customers require a first name or last name")
      end
    elsif organization_customer?
      if organization_name.blank?
        errors.add(:organization_name, "is required for organization customers")
      end
    end
  end

  def preferred_contact_primary_fields
    case preferred_contact_method
    when "phone"
      errors.add(:primary_phone, "is required when preferred contact is phone") if primary_phone.blank?
    when "email"
      errors.add(:primary_email, "is required when preferred contact is email") if primary_email.blank?
    end
  end

  def phones_are_e164_or_blank
    validate_e164(:primary_phone, primary_phone)
    validate_e164(:alternate_phone, alternate_phone)
  end

  def validate_e164(attribute, value)
    return if value.blank?
    return if value.match?(/\A\+[1-9]\d{6,14}\z/)

    errors.add(
      attribute,
      "must be a valid E.164 phone number (include the country code when outside Canada or the United States)"
    )
  end

  def emails_look_reasonable
    validate_email(:primary_email, primary_email)
    validate_email(:alternate_email, alternate_email)
  end

  def validate_email(attribute, value)
    return if value.blank?
    return if value.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)

    errors.add(attribute, "is not a valid email address")
  end
end
