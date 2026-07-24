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
    assert body["results"].any? { |r| r["id"] == vendors(:inactive_vendor).id }
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
