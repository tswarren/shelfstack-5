# frozen_string_literal: true

# Stages a Pos::PendingApprovalAction and redirects back to the POS context so the
# approval interrupt overlay opens on the next page load (Phase 11.2A).
module PosPendingApprovalStaging
  private

  def stage_pending_approval!(action:, fingerprint:, payload:, presentation:)
    Pos::PendingApprovalAction.store(
      session,
      action: action,
      fingerprint: fingerprint,
      payload: payload,
      presentation: presentation
    )
  end
end
