# frozen_string_literal: true

require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists products" do
    get products_path
    assert_response :success
    assert_match "The Illustrated Man", response.body
  end

  test "edit form uses shared record pickers for classification links" do
    product = products(:sample_book)
    get edit_product_path(product)
    assert_response :success
    assert_match "data-controller=\"record-picker\"", response.body
    assert_match "data-record-picker-record-type-value=\"merchandise_class\"", response.body
    assert_match "data-record-picker-record-type-value=\"department\"", response.body
    assert_match "data-record-picker-record-type-value=\"product_format\"", response.body
    assert_match "data-record-picker-record-type-value=\"tax_category\"", response.body
    assert_no_match(/name="product\[merchandise_class_id\]"[^>]*<option/m, response.body)
  end

  test "searches by normalized ISBN-10 input" do
    get products_path, params: { q: "0-306-40615-2" }
    assert_response :success
    assert_match "The Illustrated Man", response.body
  end

  test "creates product through service" do
    assert_difference "Product.count", 1 do
      post products_path, params: {
        identifier: "",
        product: {
          name: "Created Via UI",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          merchandise_class_id: merchandise_classes(:fiction_primary).id,
          default_department_id: departments(:books_new).id,
          default_tax_category_id: tax_categories(:physical_book).id,
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 1599,
          sellable: true,
          status: "active"
        }
      }
    end

    product = Product.order(:id).last
    assert_redirected_to product_path(product)
    assert_match(/\A29\d{11}\z/, product.identifier)
  end

  test "shows explicit identifier warning when checksum fails" do
    assert_no_difference "Product.count" do
      post products_path, params: {
        identifier: "9781786798986",
        product: {
          name: "Mavericks",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 2495,
          sellable: true,
          status: "active"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/invalid EAN-13 check digit/, response.body)
    assert_match(/Accept identifier warning/, response.body)
  end

  test "denies clerk without catalog permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get products_path
    assert_redirected_to root_path
  end

  test "validation rerender does not disclose foreign-organization classification labels" do
    foreign = create_foreign_organization_catalog!
    product = products(:sample_book)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        merchandise_class_id: foreign[:merchandise_class].id,
        default_department_id: foreign[:department].id,
        default_tax_category_id: foreign[:tax_category].id,
        status: product.status,
        sellable: product.sellable
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_response :unprocessable_entity
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_CLASS_NAME)}/, response.body)
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_TAX_NAME)}/, response.body)
    assert_no_match(/Foreign Department SECRET/, response.body)
    assert_match(/must belong to the same organization/, response.body)
  end

  test "editor without deactivate can edit an already nonsellable product" do
    product = products(:sample_book)
    product.update!(sellable: false)
    variant = product.product_variants.first

    delete session_path
    post session_path, params: { username: "cateditor", password: "password123" }

    patch product_path(product), params: {
      product: {
        name: "Edited Without Deactivate",
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: false
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    assert_equal "Edited Without Deactivate", product.reload.name
  end

  test "editor without deactivate cannot transition sellable product to nonsellable" do
    product = products(:sample_book)
    variant = product.product_variants.first
    assert product.sellable?

    delete session_path
    post session_path, params: { username: "cateditor", password: "password123" }

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: "active",
        sellable: false
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: true,
        status: "active"
      }
    }

    assert_redirected_to root_path
    assert product.reload.sellable?
  end

  test "creates a product with ordered creator assignments" do
    bradbury = creators(:ray_bradbury)
    le_guin = creators(:ursula_le_guin)

    assert_difference "Product.count", 1 do
      post products_path, params: {
        identifier: "",
        product: {
          name: "Created With Creators",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          merchandise_class_id: merchandise_classes(:fiction_primary).id,
          default_department_id: departments(:books_new).id,
          default_tax_category_id: tax_categories(:physical_book).id,
          status: "active",
          sellable: true,
          creator_assignments_provided: "1",
          creator_assignments: [
            { creator_id: le_guin.id, role: "author" },
            { creator_id: bradbury.id, role: "illustrator" }
          ]
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 1599,
          sellable: true,
          status: "active"
        }
      }
    end

    product = Product.order(:id).last
    assert_redirected_to product_path(product)
    assert_equal [ le_guin.id, bradbury.id ], product.product_creators.order(:position).pluck(:creator_id)
  end

  test "update without creator_assignments_provided leaves existing creator links untouched" do
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: "Renamed Without Touching Creators",
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    assert_equal [ creator.id ], product.product_creators.reload.pluck(:creator_id)
  end

  test "update with an explicit empty creator_assignments array clears existing links" do
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        creator_assignments_provided: "1",
        creator_assignments: []
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    assert_empty product.product_creators.reload
  end

  test "validation rerender does not disclose a foreign-organization creator label" do
    foreign = create_foreign_organization_catalog!
    product = products(:sample_book)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        creator_assignments_provided: "1",
        creator_assignments: [ { creator_id: foreign[:creator].id, role: "author" } ]
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_response :unprocessable_entity
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_CREATOR_NAME)}/, response.body)
  end

  test "update with credited_as over 255 characters returns unprocessable and leaves links unchanged" do
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    variant = product.product_variants.first
    le_guin = creators(:ursula_le_guin)

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        creator_assignments_provided: "1",
        creator_assignments: [ { creator_id: le_guin.id, role: "author", credited_as: "x" * 256 } ]
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_response :unprocessable_entity
    assert_equal [ creator.id ], product.product_creators.reload.pluck(:creator_id)
  end

  test "persists partial publication date entered as separate year/month parts" do
    product = products(:sample_book)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        publication_date_precision: "month",
        publication_date_year: "2020",
        publication_date_month: "5",
        publication_date_day: ""
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    product.reload
    assert_equal Date.new(2020, 5, 1), product.publication_date
    assert_equal "month", product.publication_date_precision
  end
end
