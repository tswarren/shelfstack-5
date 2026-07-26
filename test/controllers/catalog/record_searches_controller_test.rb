# frozen_string_literal: true

require "test_helper"

class Catalog::RecordSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "returns json results for product search" do
    get catalog_record_searches_path, params: { type: "product", q: "Illustrated" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert body["results"].is_a?(Array)
    assert body["results"].any? { |r| r["label"].include?("Illustrated") }
  end

  test "excludes inactive vendors by default" do
    get catalog_record_searches_path, params: { type: "vendor", q: "Old" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert_empty body["results"]
  end

  test "includes inactive vendors when requested" do
    get catalog_record_searches_path, params: { type: "vendor", q: "Old", include_inactive: "1" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    row = body["results"].find { |r| r["id"] == vendors(:inactive_vendor).id }
    assert row
    assert row["inactive"]
    assert_match(/Inactive/, row["label"])
  end

  test "excludes variants of inactive products by default" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)
    product.update!(status: "inactive")

    get catalog_record_searches_path, params: { type: "product_variant", q: variant.sku }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert body["results"].none? { |r| r["id"] == variant.id }
  end

  test "rejects unknown type" do
    get catalog_record_searches_path, params: { type: "nope", q: "x" }, as: :json
    assert_response :unprocessable_entity
  end

  test "denies clerk without catalog permission for products" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get catalog_record_searches_path, params: { type: "product", q: "Illustrated" }, as: :json
    assert_response :forbidden
  end

  test "denies customer search without view or lookup" do
    store = stores(:main_street)
    user = User.create!(
      username: "pos_only_#{SecureRandom.hex(2)}",
      user_number: rand(10_000..99_999),
      first_name: "Pos", last_name: "Only",
      password: "password123",
      active: true, default_store: store
    )
    role = Role.create!(
      organization: store.organization, code: "pos_only_#{user.username}", name: "POS only", active: true
    )
    RolePermission.create!(role: role, permission: Permission.find_by!(code: "pos.access"))
    StoreMembership.create!(user: user, store: store, role: role, active: true)

    delete session_path
    post session_path, params: { username: user.username, password: "password123" }

    get catalog_record_searches_path, params: { type: "customer", q: "Jordan" }, as: :json
    assert_response :forbidden
  end

  test "allows customer search with lookup permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get catalog_record_searches_path, params: { type: "customer", q: "Jordan" }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body["results"].any? { |r| r["id"] == customers(:jordan_lee).id }
  end

  test "customer phone search matches formatted numbers and shows identifying references" do
    customer = customers(:jordan_lee)
    customer.update!(city: "Waterloo")

    get catalog_record_searches_path,
        params: { type: "customer", q: "(519) 555-0123" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    row = body["results"].find { |result| result["id"] == customer.id }
    assert row
    assert_includes row["label"], customer.customer_number
    assert_includes row["label"], customer.primary_phone
    assert_includes row["label"], customer.primary_email
    assert_includes row["label"], "Waterloo"
  end

  test "isolates results to current organization" do
    get catalog_record_searches_path, params: { type: "vendor", q: "Ingram" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    ids = body["results"].map { |r| r["id"] }
    assert_includes ids, vendors(:acme_distributor).id
    other_org_vendors = Vendor.where.not(organization_id: organizations(:acme).id)
    assert(ids.none? { |id| other_org_vendors.exists?(id: id) })
  end
end
