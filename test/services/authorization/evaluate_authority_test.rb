# frozen_string_literal: true

require "test_helper"

module Authorization
  class EvaluateAuthorityTest < ActiveSupport::TestCase
    test "allows when requested value within membership override" do
      result = EvaluateAuthority.call(
        user: users(:admin),
        store: stores(:main_street),
        limit_key: :maximum_discount_rate,
        requested_value: 0.05
      )
      assert result.allow?
      assert result.proceed?
      assert_equal :store_membership, result.source
    end

    test "requires_approval when exceeding configured limit and does not proceed" do
      result = EvaluateAuthority.call(
        user: users(:admin),
        store: stores(:main_street),
        limit_key: :maximum_discount_rate,
        requested_value: 0.50
      )
      assert result.requires_approval?
      assert_not result.proceed?
      assert_equal BigDecimal("0.1"), result.configured_limit
    end

    test "denies as unconfigured when membership override is null" do
      result = EvaluateAuthority.call(
        user: users(:clerk),
        store: stores(:main_street),
        limit_key: :maximum_discount_rate,
        requested_value: 0.01
      )
      assert result.deny?
      assert_equal :unconfigured, result.source
      assert_not result.proceed?
    end

    test "unknown limit key fails closed" do
      result = EvaluateAuthority.call(
        user: users(:admin),
        store: stores(:main_street),
        limit_key: :not_a_real_limit,
        requested_value: 1
      )
      assert result.deny?
      assert_equal :unknown_limit_key, result.source
    end
  end
end
