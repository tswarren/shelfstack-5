# frozen_string_literal: true

require "test_helper"

class ApplicationServiceTest < ActiveSupport::TestCase
  class EchoService < ApplicationService
    def initialize(value)
      @value = value
    end

    def call
      @value
    end
  end

  test "call class method invokes instance call" do
    assert_equal :ok, EchoService.call(:ok)
  end

  test "application service constant loads" do
    assert_kind_of Class, ApplicationService
    assert ApplicationService < Object
  end
end
