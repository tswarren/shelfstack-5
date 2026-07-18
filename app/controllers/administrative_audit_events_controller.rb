# frozen_string_literal: true

class AdministrativeAuditEventsController < ApplicationController
  before_action -> { require_permission!("administration.audit.view") }

  def index
    @events = Current.organization.administrative_audit_events.order(created_at: :desc).limit(100)
  end
end
