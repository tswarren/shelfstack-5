# frozen_string_literal: true

# INV-ORG-001 and index_organizations_singleton normally forbid a second Organization.
# Disclosure tests need a real out-of-organization row; temporarily drop the singleton
# index inside the test transaction (PostgreSQL rolls DDL back with the transaction).
module ForeignOrganizationHelper
  SECRET_PRODUCT_NAME = "Foreign Product SECRET TITLE"
  SECRET_PRODUCT_IDENTIFIER = "9780000999995"
  SECRET_VARIANT_NAME = "Foreign Variant SECRET"
  SECRET_VARIANT_SKU = "2899999999994"
  SECRET_VENDOR_NAME = "Foreign Vendor SECRET"
  SECRET_VENDOR_CODE = "FRGVND"
  SECRET_CLASS_NAME = "Foreign Class SECRET"
  SECRET_TAX_NAME = "Foreign Tax SECRET"
  SECRET_CREATOR_NAME = "Foreign Creator SECRET"

  def create_foreign_organization_catalog!
    ActiveRecord::Base.connection.execute("DROP INDEX IF EXISTS index_organizations_singleton")

    now = Time.current
    Organization.insert!({
      code: "frgnorg",
      name: "Foreign Org Books",
      legal_name: "Foreign Org LLC",
      default_currency_code: "USD",
      default_timezone: "America/New_York",
      active: true,
      created_at: now,
      updated_at: now
    })
    organization = Organization.find_by!(code: "frgnorg")

    product_format = ProductFormat.create!(
      organization: organization,
      code: "foreign_hc",
      name: "Foreign Hardcover",
      short_code: "FH",
      format_family: "book",
      default_inventory_tracking_mode: "quantity",
      active: true
    )
    tax_category = TaxCategory.create!(
      organization: organization,
      code: "FOREIGN_TAX",
      name: SECRET_TAX_NAME,
      active: true
    )
    department = Department.create!(
      organization: organization,
      department_number: "510",
      code: "foreign_books",
      name: "Foreign Department SECRET",
      postable: true,
      active: true,
      default_tax_category: tax_category
    )
    merchandise_class = MerchandiseClass.create!(
      organization: organization,
      code: "FOREIGN_MC",
      name: SECRET_CLASS_NAME,
      level: "primary",
      active: true,
      default_department: department,
      default_tax_category: tax_category
    )
    product = Product.create!(
      organization: organization,
      identifier: SECRET_PRODUCT_IDENTIFIER,
      identifier_generated: false,
      identifier_validation_status: "valid",
      name: SECRET_PRODUCT_NAME,
      product_type: "book",
      product_format: product_format,
      merchandise_class: merchandise_class,
      default_department: department,
      default_tax_category: tax_category,
      status: "active",
      sellable: false,
      variant_structure: "single"
    )
    variant = ProductVariant.create!(
      product: product,
      sku: SECRET_VARIANT_SKU,
      name: SECRET_VARIANT_NAME,
      inventory_tracking_mode: "quantity",
      regular_price_cents: 1000,
      status: "active",
      sellable: true,
      purchasable: true
    )
    vendor = Vendor.create!(
      organization: organization,
      code: SECRET_VENDOR_CODE,
      name: SECRET_VENDOR_NAME,
      active: true
    )
    creator = Creator.create!(
      organization: organization,
      display_name: SECRET_CREATOR_NAME,
      sort_name: SECRET_CREATOR_NAME,
      active: true
    )

    {
      organization: organization,
      product: product,
      variant: variant,
      vendor: vendor,
      merchandise_class: merchandise_class,
      tax_category: tax_category,
      department: department,
      product_format: product_format,
      creator: creator
    }
  end
end
