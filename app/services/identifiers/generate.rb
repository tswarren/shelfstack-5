# frozen_string_literal: true

module Identifiers
  class Generate < ApplicationService
    class SequenceOverflowError < StandardError; end

    MAX_PAYLOAD = 9_999_999_999

    def initialize(namespace:)
      @namespace = namespace.to_s
    end

    def call
      raise ArgumentError, "unknown namespace" unless IdentifierSequence::NAMESPACES.include?(@namespace)

      ActiveRecord::Base.transaction do
        sequence = IdentifierSequence.lock.find(@namespace)
        payload = sequence.next_value

        if payload > MAX_PAYLOAD
          raise SequenceOverflowError,
                "identifier sequence #{@namespace} exceeded ten-digit payload capacity"
        end

        sequence.update!(next_value: payload + 1)
        compose_ean13(@namespace, payload)
      end
    end

    private

    def compose_ean13(namespace, payload)
      twelve = "#{namespace}#{payload.to_s.rjust(10, "0")}"
      "#{twelve}#{ean13_check_digit(twelve)}"
    end

    def ean13_check_digit(twelve_digits)
      sum = twelve_digits.chars.each_with_index.sum do |char, index|
        digit = char.to_i
        index.even? ? digit : digit * 3
      end
      (10 - (sum % 10)) % 10
    end
  end
end
