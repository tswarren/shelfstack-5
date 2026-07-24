# frozen_string_literal: true

require "test_helper"

class CatalogReplaceProductCreatorsTest < ActiveSupport::TestCase
  setup do
    @product = products(:sample_book)
    @actor = users(:admin)
    @store = stores(:main_street)
    @bradbury = creators(:ray_bradbury)
    @le_guin = creators(:ursula_le_guin)
  end

  test "OMIT sentinel preserves existing links untouched" do
    ProductCreator.create!(product: @product, creator: @bradbury, role: "author", position: 0)

    result = Catalog::ReplaceProductCreators.call(
      product: @product, assignments: Catalog::ReplaceProductCreators::OMIT, actor: @actor, store: @store
    )

    assert result
    assert_equal [ @bradbury.id ], @product.product_creators.reload.pluck(:creator_id)
  end

  test "nil assignments preserves existing links untouched" do
    ProductCreator.create!(product: @product, creator: @bradbury, role: "author", position: 0)

    result = Catalog::ReplaceProductCreators.call(
      product: @product, assignments: nil, actor: @actor, store: @store
    )

    assert result
    assert_equal [ @bradbury.id ], @product.product_creators.reload.pluck(:creator_id)
  end

  test "empty array intentionally clears all existing links" do
    ProductCreator.create!(product: @product, creator: @bradbury, role: "author", position: 0)

    result = Catalog::ReplaceProductCreators.call(
      product: @product, assignments: [], actor: @actor, store: @store
    )

    assert result
    assert_empty @product.product_creators.reload
  end

  test "replaces the collection with contiguous zero-based positions derived from array order" do
    ProductCreator.create!(product: @product, creator: @bradbury, role: "author", position: 0)

    result = Catalog::ReplaceProductCreators.call(
      product: @product,
      assignments: [
        { creator_id: @le_guin.id, role: "author", credited_as: nil },
        { creator_id: @bradbury.id, role: "illustrator", credited_as: "Ray B." }
      ],
      actor: @actor,
      store: @store
    )

    assert result
    ordered = @product.product_creators.reload.order(:position)
    assert_equal [ @le_guin.id, @bradbury.id ], ordered.pluck(:creator_id)
    assert_equal [ 0, 1 ], ordered.pluck(:position)
    assert_equal "illustrator", ordered.second.role
    assert_equal "Ray B.", ordered.second.credited_as
  end

  test "ignores any submitted position values since positions are service-authoritative" do
    result = Catalog::ReplaceProductCreators.call(
      product: @product,
      assignments: [
        { creator_id: @bradbury.id, role: "author", position: 99 },
        { creator_id: @le_guin.id, role: "author", position: 1 }
      ],
      actor: @actor,
      store: @store
    )

    assert result
    ordered = @product.product_creators.reload.order(:position)
    assert_equal [ 0, 1 ], ordered.pluck(:position)
  end

  test "rejects a foreign-organization creator id without disclosing its name and leaves existing links untouched" do
    foreign = create_foreign_organization_catalog!
    ProductCreator.create!(product: @product, creator: @bradbury, role: "author", position: 0)

    result = Catalog::ReplaceProductCreators.call(
      product: @product,
      assignments: [ { creator_id: foreign[:creator].id, role: "author" } ],
      actor: @actor,
      store: @store
    )

    assert_not result
    assert_includes @product.errors[:creator_assignments].join, "creator could not be found"
    assert_not_includes @product.errors[:creator_assignments].join, ForeignOrganizationHelper::SECRET_CREATOR_NAME
    assert_equal [ @bradbury.id ], @product.product_creators.reload.pluck(:creator_id)
  end

  test "rejects an unknown role without persisting any change" do
    ProductCreator.create!(product: @product, creator: @bradbury, role: "author", position: 0)

    result = Catalog::ReplaceProductCreators.call(
      product: @product,
      assignments: [ { creator_id: @le_guin.id, role: "ghostwriter" } ],
      actor: @actor,
      store: @store
    )

    assert_not result
    assert_equal [ @bradbury.id ], @product.product_creators.reload.pluck(:creator_id)
  end

  test "rejects a duplicate creator and role within the same submitted array" do
    result = Catalog::ReplaceProductCreators.call(
      product: @product,
      assignments: [
        { creator_id: @bradbury.id, role: "author" },
        { creator_id: @bradbury.id, role: "author" }
      ],
      actor: @actor,
      store: @store
    )

    assert_not result
    assert_includes @product.errors[:creator_assignments].join, "already assigned"
  end

  test "rejects a non-array assignments payload" do
    result = Catalog::ReplaceProductCreators.call(
      product: @product, assignments: "not-an-array", actor: @actor, store: @store
    )

    assert_not result
    assert_includes @product.errors[:creator_assignments].join, "must be an array"
  end

  test "records an audit event only when the link collection actually changes" do
    assert_difference -> { AdministrativeAuditEvent.count }, 1 do
      Catalog::ReplaceProductCreators.call(
        product: @product,
        assignments: [ { creator_id: @bradbury.id, role: "author" } ],
        actor: @actor,
        store: @store
      )
    end

    assert_no_difference -> { AdministrativeAuditEvent.count } do
      Catalog::ReplaceProductCreators.call(
        product: @product, assignments: Catalog::ReplaceProductCreators::OMIT, actor: @actor, store: @store
      )
    end
  end

  test "audit event captures before and after snapshots" do
    Catalog::ReplaceProductCreators.call(
      product: @product,
      assignments: [ { creator_id: @bradbury.id, role: "author" } ],
      actor: @actor,
      store: @store
    )

    event = AdministrativeAuditEvent.where(action: "catalog.product.creators_replaced").order(:created_at).last
    assert_equal [], event.metadata["before"]
    assert_equal 1, event.metadata["after"].size
    assert_equal @bradbury.id, event.metadata["after"].first["creator_id"]
  end
end
