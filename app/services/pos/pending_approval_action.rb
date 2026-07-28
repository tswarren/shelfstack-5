# frozen_string_literal: true

module Pos
  # Session-staged pending POS action awaiting contextual approval (Phase 11.2A).
  # Stores replayable params (never PIN), a material-value fingerprint, and
  # presentation copy for the approval interrupt overlay.
  class PendingApprovalAction
    SESSION_KEY = :pos_pending_approval_action
    TTL_SECONDS = 15 * 60

    Presentation = Data.define(:title, :action_summary, :boundary, :material_values, :effect)

    def self.store(session, action:, fingerprint:, payload:, presentation:)
      session[SESSION_KEY] = {
        "action" => action.to_s,
        "fingerprint" => fingerprint.to_s,
        "payload" => stringify_keys(payload),
        "presentation" => stringify_keys(presentation.to_h),
        "stored_at" => Time.current.to_i
      }
    end

    def self.load(session)
      raw = session[SESSION_KEY]
      return nil if raw.blank?
      return nil if expired?(raw)

      new(
        action: raw["action"],
        fingerprint: raw["fingerprint"],
        payload: raw["payload"] || {},
        presentation: Presentation.new(
          title: raw.dig("presentation", "title").to_s,
          action_summary: raw.dig("presentation", "action_summary").to_s,
          boundary: raw.dig("presentation", "boundary").to_s,
          material_values: raw.dig("presentation", "material_values").to_s,
          effect: raw.dig("presentation", "effect").to_s
        ),
        stored_at: raw["stored_at"].to_i
      )
    end

    def self.clear!(session)
      session.delete(SESSION_KEY)
    end

    def self.expired?(raw)
      stored_at = raw["stored_at"].to_i
      stored_at <= 0 || (Time.current.to_i - stored_at) > TTL_SECONDS
    end

    def self.stringify_keys(hash)
      hash.to_h.transform_keys(&:to_s).transform_values { |v| v.is_a?(Hash) ? stringify_keys(v) : v }
    end
    private_class_method :stringify_keys, :expired?

    attr_reader :action, :fingerprint, :payload, :presentation, :stored_at

    def initialize(action:, fingerprint:, payload:, presentation:, stored_at:)
      @action = action.to_s
      @fingerprint = fingerprint.to_s
      @payload = payload.to_h
      @presentation = presentation
      @stored_at = stored_at
    end

    def matches_fingerprint?(computed)
      ActiveSupport::SecurityUtils.secure_compare(@fingerprint, computed.to_s)
    end
  end
end
