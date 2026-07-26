# frozen_string_literal: true

class MigrateProductRequestsToCustomerId < ActiveRecord::Migration[8.1]
  class MigrationCustomer < ActiveRecord::Base
    self.table_name = "customers"
  end

  class MigrationProductRequest < ActiveRecord::Base
    self.table_name = "product_requests"
  end

  class MigrationOrganization < ActiveRecord::Base
    self.table_name = "organizations"
  end

  def up
    add_reference :product_requests, :customer, foreign_key: { on_delete: :restrict }

    backfill_customer_references!

    remove_column :product_requests, :customer_reference, :string
  end

  def down
    add_column :product_requests, :customer_reference, :string

    MigrationProductRequest.reset_column_information
    MigrationProductRequest.where.not(customer_id: nil).find_each do |request|
      customer = MigrationCustomer.find_by(id: request.customer_id)
      next unless customer

      label = [ customer.first_name, customer.last_name, customer.organization_name ].compact_blank.join(" ")
      request.update_columns(customer_reference: label.presence || "Legacy customer")
    end

    remove_reference :product_requests, :customer, foreign_key: true
  end

  private

  def backfill_customer_references!
    org = MigrationOrganization.order(:id).first
    return unless org

    references = MigrationProductRequest
      .where.not(customer_reference: [ nil, "" ])
      .distinct
      .pluck(:customer_reference)

    map = {}
    references.each do |raw|
      number = generate_customer_number!
      first_name = sanitize_first_name(raw)
      customer = MigrationCustomer.create!(
        organization_id: org.id,
        customer_number: number,
        customer_type: "individual",
        first_name: first_name,
        preferred_contact_method: "none",
        active: true
      )
      map[raw] = customer.id
    end

    map.each do |raw, customer_id|
      MigrationProductRequest.where(customer_reference: raw).update_all(customer_id: customer_id)
    end
  end

  def sanitize_first_name(raw)
    cleaned = raw.to_s.strip.gsub(/\s+/, " ")
    return "Legacy customer" if cleaned.blank?

    cleaned.truncate(100, omission: "")
  end

  def generate_customer_number!
    # Inline allocation matching Identifiers::Generate for namespace 22 during migration.
    payload = nil

    ActiveRecord::Base.transaction do
      row = ActiveRecord::Base.connection.select_one(
        "SELECT next_value FROM identifier_sequences WHERE namespace = '22' FOR UPDATE"
      )
      raise "missing identifier sequence 22" unless row

      payload = row["next_value"].to_i
      ActiveRecord::Base.connection.execute(
        "UPDATE identifier_sequences SET next_value = #{payload + 1}, updated_at = CURRENT_TIMESTAMP WHERE namespace = '22'"
      )
    end

    twelve = format("22%010d", payload)
    "#{twelve}#{ean13_check_digit(twelve)}"
  end

  def ean13_check_digit(twelve_digits)
    sum = twelve_digits.chars.each_with_index.sum do |char, index|
      digit = char.to_i
      index.even? ? digit : digit * 3
    end
    (10 - (sum % 10)) % 10
  end
end
