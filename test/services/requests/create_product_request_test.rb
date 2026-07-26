# frozen_string_literal: true

require "test_helper"

module Requests
  class CreateProductRequestTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @product = products(:upc_product)
      @variant = product_variants(:upc_product_standard)
      @admin = users(:admin)
      @clerk = users(:clerk)
    end

    test "creates an open request without changing on_hand or on_order" do
      balance_before = Purchasing::OnOrder.call(store: @store, product_variant: @variant)

      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "stock_replenishment", product_id: @product.id,
                      product_variant_id: @variant.id, requested_quantity: 4, priority: "high" }
      )

      assert result.success?, result.error
      assert_equal "open", result.product_request.status
      assert_equal @admin, result.product_request.requested_by_user
      assert_equal balance_before, Purchasing::OnOrder.call(store: @store, product_variant: @variant)
      assert_nil StockBalance.find_by(store: @store, product_variant: @variant)
    end

    test "requires a product" do
      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "staff_suggestion", requested_quantity: 1 }
      )

      assert_not result.success?
      assert_match(/Product/i, result.error)
    end

    test "customer_request requires a contactable customer and not a variant" do
      customer = customers(:jordan_lee)

      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "customer_request", product_id: @product.id,
                      requested_quantity: 1, customer_id: customer.id }
      )

      assert result.success?, result.error
      assert result.product_request.customer_request?
      assert_equal customer.id, result.product_request.customer_id
      assert_nil result.product_request.product_variant_id
    end

    test "customer_request rejects non-contactable customer" do
      customer = customers(:inactive_patron)
      customer.update!(active: true, preferred_contact_method: "none")

      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "customer_request", product_id: @product.id,
                      requested_quantity: 1, customer_id: customer.id }
      )

      assert_not result.success?
      assert_match(/contactable/i, result.error)
    end

    test "denies an actor without requests.product_request.create" do
      result = CreateProductRequest.call(
        store: @store,
        actor: @clerk,
        attributes: { request_type: "staff_suggestion", product_id: @product.id, requested_quantity: 1 }
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "denies customer assignment without customer view or lookup" do
      actor = request_writer_without_customer_access

      result = CreateProductRequest.call(
        store: @store,
        actor: actor,
        attributes: {
          request_type: "staff_suggestion",
          product_id: @product.id,
          requested_quantity: 1,
          customer_id: customers(:jordan_lee).id
        }
      )

      assert_not result.success?
      assert_match(/not permitted to assign customers/i, result.error)
    end

    test "records an audit event" do
      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "staff_suggestion", product_id: @product.id, requested_quantity: 1 }
      )

      assert result.success?, result.error
      event = AdministrativeAuditEvent.where(action: "requests.product_request.created", subject_id: result.product_request.id).last
      assert event
      assert_equal @admin, event.actor_user
    end

    private

    def request_writer_without_customer_access
      user = User.create!(
        username: "req_writer_#{SecureRandom.hex(2)}",
        user_number: rand(10_000..99_999),
        first_name: "Req", last_name: "Writer",
        password: "password123",
        active: true, default_store: @store
      )
      role = Role.create!(
        organization: @store.organization,
        code: "req_writer_#{user.username}",
        name: "Request writer",
        active: true
      )
      %w[requests.product_request.create requests.product_request.edit].each do |code|
        RolePermission.create!(role: role, permission: Permission.find_by!(code: code))
      end
      StoreMembership.create!(user: user, store: @store, role: role, active: true)
      user
    end
  end
end
