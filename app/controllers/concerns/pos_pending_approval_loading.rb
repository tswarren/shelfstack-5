# frozen_string_literal: true

# Loads and clears Phase 11.2A pending approval actions for POS pages.
module PosPendingApprovalLoading
  extend ActiveSupport::Concern

  included do
    before_action :load_pending_approval_action, if: :load_pending_approval_action?
  end

  private

  def load_pending_approval_action?
    false
  end

  def load_pending_approval_action
    @pending_approval_action = Pos::PendingApprovalAction.load(session)
    Pos::PendingApprovalAction.clear!(session) if @pending_approval_action.nil? && session[Pos::PendingApprovalAction::SESSION_KEY].present?
  end
end
