# frozen_string_literal: true

require "test_helper"

class CatalogSearchRecordsTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "searches merchandise classes by name within organization" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "merchandise_class",
      query: "fiction"
    )

    assert results.any?
    assert results.any? { |r| r.id == merchandise_classes(:fiction_primary).id }
    assert results.all? { |r| r.label.present? }
  end

  test "excludes inactive vendors by default" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "Old"
    )

    assert_empty results.map(&:id)
  end

  test "includes inactive vendors when requested" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "Old",
      include_inactive: true
    )

    assert_includes results.map(&:id), vendors(:inactive_vendor).id
  end

  test "scopes product variants by product_id" do
    product = products(:sample_book)

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: "",
      product_id: product.id
    )

    assert results.any?
    variant_ids = ProductVariant.where(id: results.map(&:id)).pluck(:product_id).uniq
    assert_equal [ product.id ], variant_ids
  end

  test "rejects unknown record type" do
    assert_raises(ArgumentError) do
      Catalog::SearchRecords.call(organization: @organization, record_type: "nope", query: "x")
    end
  end

  test "searches creators by display, sort, and normalized name" do
    creator = Creator.create!(
      organization: @organization, display_name: "Ursula K. Le Guin", sort_name: "Le Guin, Ursula K."
    )

    results = Catalog::SearchRecords.call(organization: @organization, record_type: "creator", query: "le guin")

    assert_includes results.map(&:id), creator.id
    match = results.find { |r| r.id == creator.id }
    assert_equal "Ursula K. Le Guin — Le Guin, Ursula K.", match.label
  end

  test "excludes inactive creators by default and includes them with disambiguation when requested" do
    creator = Creator.create!(
      organization: @organization, display_name: "Same Name", sort_name: "Same Name", active: false
    )

    default_results = Catalog::SearchRecords.call(organization: @organization, record_type: "creator", query: "Same Name")
    assert_not_includes default_results.map(&:id), creator.id

    with_inactive = Catalog::SearchRecords.call(
      organization: @organization, record_type: "creator", query: "Same Name", include_inactive: true
    )
    match = with_inactive.find { |r| r.id == creator.id }
    assert match
    assert match.inactive
    assert_equal "Same Name — Creator #{creator.id}", match.label.split(" · ").first
  end

  test "authorized? checks permission codes" do
    admin = users(:admin)
    store = stores(:main_street)

    assert Catalog::SearchRecords.authorized?(user: admin, store: store, record_type: "product")
  end

  test "excludes active variant when parent product is inactive" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)
    product.update!(status: "inactive")

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: variant.sku
    )

    assert_not_includes results.map(&:id), variant.id
  end

  test "includes inactive-product variant with status suffix when requested" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)
    product.update!(status: "inactive")

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: variant.sku,
      include_inactive: true
    )

    match = results.find { |r| r.id == variant.id }
    assert match
    assert match.inactive
    assert_match(/Inactive/, match.label)
  end

  test "finds variants by product identifier" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: product.identifier
    )

    assert_includes results.map(&:id), variant.id
  end

  test "finds variants by creator name" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)
    creator = creators(:ursula_le_guin)
    ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: "le guin"
    )

    assert_includes results.map(&:id), variant.id
  end

  test "inactive vendor results include inactive flag when requested" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "Old",
      include_inactive: true
    )

    match = results.find { |r| r.id == vendors(:inactive_vendor).id }
    assert match
    assert match.inactive
    assert_match(/Inactive/, match.label)
  end

  test "treats percent and underscore as literal search characters" do
    percent_vendor = Vendor.create!(
      organization: @organization,
      code: "PCT100",
      name: "100% Returns Co",
      active: true
    )
    underscore_vendor = Vendor.create!(
      organization: @organization,
      code: "US_VND",
      name: "Trade_Book Supply",
      active: true
    )
    ordinary = vendors(:acme_distributor)

    percent_ids = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "%"
    ).map(&:id)

    assert_includes percent_ids, percent_vendor.id
    assert_not_includes percent_ids, ordinary.id,
                        "bare % must not act as an unrestricted SQL wildcard"

    underscore_ids = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "_"
    ).map(&:id)

    assert_includes underscore_ids, underscore_vendor.id
    assert_not_includes underscore_ids, ordinary.id,
                        "bare _ must not match arbitrary single characters"
  end

  test "searches customers by name and labels with phone email and city" do
    customer = customers(:jordan_lee)
    customer.update!(city: "London")

    results = Catalog::SearchRecords.call(
      organization: @organization, record_type: "customer", query: "Jordan"
    )

    match = results.find { |r| r.id == customer.id }
    assert match
    assert_equal customer.picker_label, match.label
    assert_match customer.customer_number, match.label
    assert_match customer.primary_phone, match.label
    assert_match customer.primary_email, match.label
    assert_match "London", match.label
  end

  test "blank customer query returns a bounded active list" do
    results = Catalog::SearchRecords.call(
      organization: @organization, record_type: "customer", query: ""
    )

    assert results.any?
    assert_includes results.map(&:id), customers(:jordan_lee).id
    assert_not_includes results.map(&:id), customers(:inactive_patron).id
  end

  test "customer number match surfaces inactive customer without include_inactive" do
    inactive = customers(:inactive_patron)

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "customer",
      query: inactive.customer_number
    )

    assert_includes results.map(&:id), inactive.id
  end

  test "authorized? allows customer view or lookup but not pos.access alone" do
    admin = users(:admin)
    store = stores(:main_street)

    assert Catalog::SearchRecords.authorized?(user: admin, store: store, record_type: "customer")

    limited = User.create!(
      username: "pos_only_#{SecureRandom.hex(2)}",
      user_number: rand(10_000..99_999),
      first_name: "Pos", last_name: "Only",
      password: "password123",
      active: true, default_store: store
    )
    role = Role.create!(
      organization: @organization, code: "pos_only_#{limited.username}", name: "POS only", active: true
    )
    RolePermission.create!(role: role, permission: Permission.find_by!(code: "pos.access"))
    StoreMembership.create!(user: limited, store: store, role: role, active: true)

    assert_not Catalog::SearchRecords.authorized?(user: limited, store: store, record_type: "customer")

    RolePermission.create!(role: role, permission: Permission.find_by!(code: "customers.customer.lookup"))
    limited_lookup = User.find(limited.id)
    assert Catalog::SearchRecords.authorized?(user: limited_lookup, store: store, record_type: "customer")
  end

  test "customer picker search ignores include_inactive for enumeration" do
    inactive = customers(:inactive_patron)

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "customer",
      query: "Patron",
      include_inactive: true
    )

    assert_not_includes results.map(&:id), inactive.id
  end
end
