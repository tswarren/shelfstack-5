# frozen_string_literal: true

# Creator manage UI (Gate 8b, phase-08 §7): index / new / create / edit /
# update. Deactivation sets `active: false`; there is no hard delete.
class CreatorsController < ApplicationController
  before_action -> { require_permission!("catalog.manage_creators") }
  before_action :set_creator, only: %i[edit update]

  def index
    @query = params[:q].to_s.strip
    scope = Current.organization.creators.order(:sort_name)
    if @query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope = scope.where("display_name ILIKE :q OR sort_name ILIKE :q", q: pattern)
    end
    @pagy, @creators = pagy(scope, limit: pagy_limit)
  end

  def new
    @creator = Current.organization.creators.new(active: true)
  end

  def create
    @creator = Current.organization.creators.new(creator_params)

    if @creator.save
      Administration::RecordAuditEvent.call(
        actor: Current.user,
        organization: Current.organization,
        store: Current.store,
        action: "catalog.creator.created",
        subject: @creator,
        metadata: { "after" => creator_snapshot(@creator) }
      )
      redirect_to creators_path, notice: "Creator created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    before = creator_snapshot(@creator)

    if @creator.update(creator_params)
      Administration::RecordAuditEvent.call(
        actor: Current.user,
        organization: Current.organization,
        store: Current.store,
        action: "catalog.creator.updated",
        subject: @creator,
        metadata: Administration::ChangeMetadata.diff(before, creator_snapshot(@creator))
      )
      redirect_to creators_path, notice: "Creator updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_creator
    @creator = Current.organization.creators.find(params[:id])
  end

  def creator_params
    params.require(:creator).permit(:display_name, :sort_name, :active)
  end

  def creator_snapshot(creator)
    Administration::ChangeMetadata.snapshot(creator, %w[display_name sort_name normalized_name active])
  end
end
