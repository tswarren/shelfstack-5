# frozen_string_literal: true

require "test_helper"

class CatalogProductImportPreviewTokenTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
    @actor = users(:admin)
    @retrieved_at = Time.zone.parse("2026-07-24 12:00:00")
    @normalized = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "0316769487",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      provider_record_id: "9780316769488",
      retrieved_at: @retrieved_at,
      title: "Test Harbor",
      list_price: { amount: "16.99", currency_code: "USD" }
    )
    @creator_suggestions = [
      Catalog::PreviewProductImport::CreatorSuggestion.new(
        display_name: "Jordan Fixture",
        role: "author",
        credited_as: nil,
        position: 0,
        resolution: :propose_create,
        matched_creator_id: nil,
        candidate_creator_ids: []
      ),
      Catalog::PreviewProductImport::CreatorSuggestion.new(
        display_name: "Alex Sample",
        role: "author",
        credited_as: nil,
        position: 1,
        resolution: :propose_create,
        matched_creator_id: nil,
        candidate_creator_ids: []
      )
    ]
  end

  test "issue and verify round-trip returns provenance list price and creator suggestions" do
    token = Catalog::ProductImportPreviewToken.issue(
      organization: @organization,
      actor: @actor,
      normalized_result: @normalized,
      warnings: [ { code: "sample", message: "ok" } ],
      creator_suggestions: @creator_suggestions
    )

    payload = Catalog::ProductImportPreviewToken.verify!(
      token: token, organization: @organization, actor: @actor
    )

    assert_equal @organization.id, payload["organization_id"]
    assert_equal @actor.id, payload["actor_user_id"]
    assert_equal "isbndb", payload["provider"]
    assert_equal "9780316769488", payload["provider_record_id"]
    assert_equal "0316769487", payload["requested_identifier"]
    assert_equal "9780316769488", payload["canonical_identifier"]
    assert_equal 1699, payload["list_price_cents"]
    assert_equal "USD", payload["list_price_currency_code"]
    assert_equal "sample", payload["accepted_warnings"].first["code"]
    assert_equal 2, payload["creator_suggestions"].size
    assert_equal "Jordan Fixture", payload["creator_suggestions"].first["display_name"]
    assert_equal "propose_create", payload["creator_suggestions"].first["resolution"]
  end

  test "resolve_creator_resolutions ignores forged name action and role for propose_create" do
    payload = {
      "creator_suggestions" => [
        {
          "position" => 0,
          "display_name" => "Jordan Fixture",
          "role" => "author",
          "credited_as" => nil,
          "resolution" => "propose_create",
          "matched_creator_id" => nil,
          "candidate_creator_ids" => []
        }
      ]
    }

    resolutions = Catalog::ProductImportPreviewToken.resolve_creator_resolutions!(
      payload: payload,
      submitted: [ {
        action: "use_existing",
        display_name: "Arbitrary Name",
        role: "illustrator",
        creator_id: creators(:ray_bradbury).id
      } ]
    )

    assert_equal [
      { action: "create", display_name: "Jordan Fixture", role: "author", credited_as: nil }
    ], resolutions
  end

  test "resolve_creator_resolutions rejects an extra submitted row" do
    payload = {
      "creator_suggestions" => [
        {
          "position" => 0,
          "display_name" => "Jordan Fixture",
          "role" => "author",
          "credited_as" => nil,
          "resolution" => "propose_create",
          "matched_creator_id" => nil,
          "candidate_creator_ids" => []
        }
      ]
    }

    assert_raises(Catalog::ProductImportPreviewToken::CreatorResolutionError) do
      Catalog::ProductImportPreviewToken.resolve_creator_resolutions!(
        payload: payload,
        submitted: [
          { action: "create", display_name: "Jordan Fixture", role: "author" },
          { action: "create", display_name: "Extra Person", role: "author" }
        ]
      )
    end
  end

  test "resolve_creator_resolutions rejects a creator id outside the signed candidate set" do
    bradbury = creators(:ray_bradbury)
    le_guin = creators(:ursula_le_guin)
    payload = {
      "creator_suggestions" => [
        {
          "position" => 0,
          "display_name" => "Ambiguous Fixture",
          "role" => "author",
          "credited_as" => nil,
          "resolution" => "require_selection",
          "matched_creator_id" => nil,
          "candidate_creator_ids" => [ bradbury.id ]
        }
      ]
    }

    assert_raises(Catalog::ProductImportPreviewToken::CreatorResolutionError) do
      Catalog::ProductImportPreviewToken.resolve_creator_resolutions!(
        payload: payload,
        submitted: [ { action: "use_existing", creator_id: le_guin.id } ]
      )
    end
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
