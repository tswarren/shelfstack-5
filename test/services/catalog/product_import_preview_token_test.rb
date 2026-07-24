# frozen_string_literal: true

require "test_helper"

class CatalogProductImportPreviewTokenTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
    @actor = users(:admin)
    @retrieved_at = Time.zone.parse("2026-07-24 12:00:00")
    @normalized = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      provider_record_id: "9780316769488",
      retrieved_at: @retrieved_at,
      title: "Test Harbor",
      list_price: { amount: "16.99", currency_code: "USD" }
    )
  end

  test "issue and verify round-trip returns provenance and list price" do
    token = Catalog::ProductImportPreviewToken.issue(
      organization: @organization,
      actor: @actor,
      normalized_result: @normalized,
      warnings: [ { code: "sample", message: "ok" } ]
    )

    payload = Catalog::ProductImportPreviewToken.verify!(
      token: token, organization: @organization, actor: @actor
    )

    assert_equal @organization.id, payload["organization_id"]
    assert_equal @actor.id, payload["actor_user_id"]
    assert_equal "isbndb", payload["provider"]
    assert_equal "9780316769488", payload["provider_record_id"]
    assert_equal "9780316769488", payload["canonical_identifier"]
    assert_equal 1699, payload["list_price_cents"]
    assert_equal "USD", payload["list_price_currency_code"]
    assert_equal "sample", payload["accepted_warnings"].first["code"]
  end

  test "expired token raises ExpiredError" do
    token = Catalog::ProductImportPreviewToken.issue(
      organization: @organization, actor: @actor, normalized_result: @normalized
    )

    travel_to 31.minutes.from_now do
      assert_raises(Catalog::ProductImportPreviewToken::ExpiredError) do
        Catalog::ProductImportPreviewToken.verify!(
          token: token, organization: @organization, actor: @actor
        )
      end
    end
  end

  test "wrong organization raises InvalidError" do
    token = Catalog::ProductImportPreviewToken.issue(
      organization: @organization, actor: @actor, normalized_result: @normalized
    )
    other = create_foreign_organization_catalog![:organization]

    assert_raises(Catalog::ProductImportPreviewToken::InvalidError) do
      Catalog::ProductImportPreviewToken.verify!(
        token: token, organization: other, actor: @actor
      )
    end
  end

  test "wrong actor raises InvalidError" do
    token = Catalog::ProductImportPreviewToken.issue(
      organization: @organization, actor: @actor, normalized_result: @normalized
    )

    assert_raises(Catalog::ProductImportPreviewToken::InvalidError) do
      Catalog::ProductImportPreviewToken.verify!(
        token: token, organization: @organization, actor: users(:clerk)
      )
    end
  end

  test "tampered token raises InvalidError" do
    token = Catalog::ProductImportPreviewToken.issue(
      organization: @organization, actor: @actor, normalized_result: @normalized
    )

    assert_raises(Catalog::ProductImportPreviewToken::InvalidError) do
      Catalog::ProductImportPreviewToken.verify!(
        token: "#{token}x", organization: @organization, actor: @actor
      )
    end
  end

  test "blank token raises InvalidError" do
    assert_raises(Catalog::ProductImportPreviewToken::InvalidError) do
      Catalog::ProductImportPreviewToken.verify!(
        token: "", organization: @organization, actor: @actor
      )
    end
  end
end
