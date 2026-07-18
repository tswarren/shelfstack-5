# frozen_string_literal: true

module Identifiers
  class Generate < ApplicationService
    class SequenceOverflowError < StandardError; end

    MAX_PAYLOAD = 9_999_999_999
    MAX_SKIP_ATTEMPTS = 1000

    # occupied: optional callable receiving a candidate EAN-13; when truthy, skip and allocate again
    # while holding the sequence lock (handles stale counters after imports/restores).
    def initialize(namespace:, occupied: nil)
      @namespace = namespace.to_s
      @occupied = occupied
    end

    def call
      raise ArgumentError, "unknown namespace" unless IdentifierSequence::NAMESPACES.include?(@namespace)

      ActiveRecord::Base.transaction do
        sequence = IdentifierSequence.lock.find(@namespace)
        attempts = 0

        loop do
          attempts += 1
          if attempts > MAX_SKIP_ATTEMPTS
            raise SequenceOverflowError,
                  "identifier sequence #{@namespace} could not find an unoccupied payload"
          end

          payload = sequence.next_value
          if payload > MAX_PAYLOAD
            raise SequenceOverflowError,
                  "identifier sequence #{@namespace} exceeded ten-digit payload capacity"
          end

          sequence.update!(next_value: payload + 1)
          candidate = compose_ean13(@namespace, payload)
          next if occupied?(candidate)

          return candidate
        end
      end
    end

    private

    def occupied?(candidate)
      return false if @occupied.nil?

      @occupied.call(candidate)
    end

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
