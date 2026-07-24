# frozen_string_literal: true

require "test_helper"

class CatalogEnrichmentEventTest < ActiveSupport::TestCase
  setup do
    @product = products(:sample_book)
    @organization = organizations(:acme)
    @actor = users(:admin)
  end

  def build_event(overrides = {})
    CatalogEnrichmentEvent.new({
      product: @product,
      organization: @organization,
      actor_user: @actor,
      provider: "isbndb",
      provider_record_id: "abc123",
      requested_identifier: @product.identifier,
      canonical_identifier: @product.identifier,
      action: "create",
      retrieved_at: Time.current,
      created_at: Time.current
    }.merge(overrides))
  end

  test "creates with default jsonb hash and array shapes" do
    event = build_event.tap(&:save!)

    assert_equal({}, event.reload.applied_fields)
    assert_equal([], event.accepted_warnings)
  end

  test "is readonly after create and update raises ActiveRecord::ReadOnlyRecord" do
    event = build_event.tap(&:save!)

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.update!(provider: "google_books")
    end
  end

  test "destroy raises ActiveRecord::ReadOnlyRecord" do
    event = build_event.tap(&:save!)

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
  end

  test "rejects an invalid action" do
    event = build_event(action: "delete")

    assert_not event.valid?
    assert_includes event.errors[:action], "is not included in the list"
  end

  test "rejects a product from a different organization" do
    foreign = create_foreign_organization_catalog!
    event = build_event(product: foreign[:product])

    assert_not event.valid?
    assert_includes event.errors[:product].join, "must belong to the same organization"
  end

  test "requires requested and canonical identifiers" do
    event = build_event(requested_identifier: nil, canonical_identifier: nil)

    assert_not event.valid?
    assert_includes event.errors[:requested_identifier], "can't be blank"
    assert_includes event.errors[:canonical_identifier], "can't be blank"
  end

  test "database check constraint rejects an out-of-allowlist action" do
    event = build_event
    event.save!(validate: false)

    invalid = build_event(action: "delete")
    assert_raises(ActiveRecord::StatementInvalid) { invalid.save!(validate: false) }
  end
end
