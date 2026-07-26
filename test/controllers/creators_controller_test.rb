# frozen_string_literal: true

require "test_helper"

class CreatorsControllerTest < ActionDispatch::IntegrationTest
  test "index requires catalog.manage_creators permission" do
    post session_path, params: { username: "clerk", password: "password123" }

    get creators_url

    assert_redirected_to root_path
  end

  test "index succeeds for a user with catalog.manage_creators" do
    post session_path, params: { username: "admin", password: "password123" }

    get creators_url

    assert_response :success
    assert_match creators(:ray_bradbury).display_name, response.body
  end

  test "index search filters by display or sort name" do
    post session_path, params: { username: "admin", password: "password123" }

    get creators_url, params: { q: "Le Guin" }

    assert_response :success
    assert_match creators(:ursula_le_guin).display_name, response.body
    assert_no_match(/#{Regexp.escape(creators(:ray_bradbury).display_name)}/, response.body)
  end

  test "create persists a new creator and records an audit event" do
    post session_path, params: { username: "admin", password: "password123" }

    assert_difference [ "Creator.count", "AdministrativeAuditEvent.count" ], 1 do
      post creators_url, params: { creator: { display_name: "Octavia E. Butler", active: true } }
    end

    assert_redirected_to creators_path
    created = Creator.order(:id).last
    assert_equal "Octavia E. Butler", created.display_name
    assert_equal "octavia e. butler", created.normalized_name
  end

  test "create with a blank display_name re-renders the form" do
    post session_path, params: { username: "admin", password: "password123" }

    assert_no_difference "Creator.count" do
      post creators_url, params: { creator: { display_name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "inline product-form create replaces only the creator picker and closes dialog" do
    post session_path, params: { username: "admin", password: "password123" }

    assert_difference "Creator.count", 1 do
      post creators_url,
           params: {
             inline_product_form: "1",
             row_index: "row42",
             creator: { display_name: "Inline Stream Creator", active: true }
           },
           as: :turbo_stream
    end

    assert_response :success
    assert_match(
      /turbo-stream[^>]*action="replace"[^>]*target="product_creator_assignment_row42_creator_picker"/,
      response.body
    )
    assert_no_match(/creator-assignment-row-row42/, response.body)
    assert_match(/turbo-stream[^>]*action="close_dialog"[^>]*target="inline-creator-dialog"/, response.body)
    assert_no_match(/<script>/, response.body)
  end

  test "inline create for a dual-role creator targets only the invoking row picker" do
    post session_path, params: { username: "admin", password: "password123" }
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    author_link = ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    illustrator_link = ProductCreator.create!(
      product: product, creator: creator, role: "illustrator", position: 1, credited_as: "Maps"
    )
    author_key = "product_creator_#{author_link.id}"
    illustrator_key = "product_creator_#{illustrator_link.id}"

    assert_difference "Creator.count", 1 do
      post creators_url,
           params: {
             inline_product_form: "1",
             row_index: illustrator_key,
             creator: { display_name: "Replacement Illustrator", active: true }
           },
           as: :turbo_stream
    end

    assert_response :success
    assert_match(
      /turbo-stream[^>]*action="replace"[^>]*target="product_creator_assignment_#{Regexp.escape(illustrator_key)}_creator_picker"/,
      response.body
    )
    assert_no_match(
      /turbo-stream[^>]*action="replace"[^>]*target="product_creator_assignment_#{Regexp.escape(author_key)}_creator_picker"/,
      response.body
    )
    assert_match(/Replacement Illustrator/, response.body)
  end

  test "update persists changes and records an audit diff" do
    post session_path, params: { username: "admin", password: "password123" }
    creator = creators(:ray_bradbury)

    patch creator_url(creator), params: { creator: { sort_name: "Bradbury, Raymond" } }

    assert_redirected_to creators_path
    assert_equal "Bradbury, Raymond", creator.reload.sort_name
    event = AdministrativeAuditEvent.where(action: "catalog.creator.updated", subject_id: creator.id).last
    assert event
    assert_equal "Bradbury, Ray", event.metadata.dig("before", "sort_name")
    assert_equal "Bradbury, Raymond", event.metadata.dig("after", "sort_name")
  end

  test "update can deactivate a creator without unlinking existing products" do
    post session_path, params: { username: "admin", password: "password123" }
    creator = creators(:ray_bradbury)
    link = ProductCreator.create!(product: products(:sample_book), creator: creator, role: "author", position: 0)

    patch creator_url(creator), params: { creator: { active: false } }

    assert_not creator.reload.active?
    assert link.reload.persisted?
  end

  test "cannot edit a creator belonging to a different organization" do
    post session_path, params: { username: "admin", password: "password123" }
    foreign = create_foreign_organization_catalog!

    get edit_creator_url(foreign[:creator])

    assert_response :not_found
  end
end
