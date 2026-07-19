# frozen_string_literal: true

# Shared helpers for assigning human-readable money/percent params onto models
# without silently clearing values on invalid input.
module HumanReadableParams
  extend ActiveSupport::Concern

  private

  # Yields the parsed cents/rate/bps on :ok, assigns nil on :blank when allowed,
  # and records an error on :invalid without clearing the domain attribute.
  def assign_parsed_param(record, attr, parsed, allow_blank: true, presentation_attr: nil)
    case parsed.status
    when :blank
      record.public_send("#{attr}=", nil) if allow_blank
    when :ok
      record.public_send("#{attr}=", parsed.value)
    when :invalid
      label = presentation_attr || attr
      record.errors.add(label, parsed.error || "is invalid")
      # Preserve raw for redisplay via instance var when controllers stash it.
      false
    end
  end

  # Hash-based attrs (before a service call): assign on :ok / optional :blank,
  # and on :invalid record an error without writing nil.
  # When +record+ is nil, errors accumulate on @human_readable_param_errors.
  def write_parsed_attr!(attrs, key, parsed, allow_blank: true, record: nil, presentation_attr: nil)
    case parsed.status
    when :blank
      attrs[key] = nil if allow_blank
      true
    when :ok
      attrs[key] = parsed.value
      true
    when :invalid
      label = presentation_attr || key
      message = parsed.error || "is invalid"
      if record
        record.errors.add(label, message)
      else
        (@human_readable_param_errors ||= []) << [ label, message ]
      end
      false
    end
  end

  def human_readable_params_invalid?
    @human_readable_param_errors.present?
  end

  def copy_human_readable_param_errors!(record)
    Array(@human_readable_param_errors).each do |attr, message|
      record.errors.add(attr, message)
    end
  end

  def parse_money_param(value)
    Forms::ParseMoney.call(value)
  end

  def parse_percent_bps_param(value)
    Forms::ParsePercent.to_bps(value)
  end

  def parse_percent_rate_param(value)
    Forms::ParsePercent.to_rate(value)
  end

  # Accept UI decimal dollars (`12.95`) or direct integer cents from tests/API.
  def money_param_to_cents(value, label:, required: true)
    if value.nil? || value.to_s.strip.blank?
      raise ArgumentError, "#{label} is required" if required
      return nil
    end

    if value.is_a?(Integer) || value.to_s.strip.match?(/\A-?\d+\z/)
      return value.to_i
    end

    parsed = Forms::ParseMoney.call(value)
    case parsed.status
    when :ok then parsed.value
    when :blank
      raise ArgumentError, "#{label} is required" if required
      nil
    else
      raise ArgumentError, "#{label} #{parsed.error}"
    end
  end

  def percent_param_to_bps(value, label:, required: false)
    parsed = Forms::ParsePercent.to_bps(value)
    case parsed.status
    when :ok then parsed.value
    when :blank
      raise ArgumentError, "#{label} is required" if required
      nil
    else
      raise ArgumentError, "#{label} #{parsed.error}"
    end
  end
end
