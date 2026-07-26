# frozen_string_literal: true

module MerchandiseClassFormHelper
  # Flat hierarchical options for the canonical merchandise-class select.
  # Includes the selected record and its ancestors even when inactive.
  def merchandise_class_select_options(organization, selected: nil)
    selected = coerce_merchandise_class(organization, selected)
    records = organization.merchandise_classes.includes(:parent).to_a
    by_id = records.index_by(&:id)
    keep_ids = Set.new(records.select(&:active?).map(&:id))
    if selected
      cursor = selected
      while cursor
        keep_ids << cursor.id
        cursor = by_id[cursor.parent_id]
      end
    end

    visible = records.select { |record| keep_ids.include?(record.id) }
    ordered = MerchandiseClass.sorted_hierarchically(visible)

    ordered.map do |record|
      label = hierarchy_path_label(record)
      label = "#{label} (inactive)" unless record.active?
      [ label, record.id, { "data-level" => record.level, "data-parent-id" => record.parent_id } ]
    end
  end

  # JSON tree for Stimulus cascade enhancement (presentation only).
  def merchandise_class_cascade_payload(organization, selected: nil)
    selected = coerce_merchandise_class(organization, selected)
    records = organization.merchandise_classes.select(:id, :name, :level, :parent_id, :active).to_a
    by_id = records.index_by(&:id)
    keep_ids = Set.new(records.select(&:active?).map(&:id))
    if selected
      cursor = selected
      while cursor
        keep_ids << cursor.id
        # Walk only organization-scoped rows — never trust association parents.
        cursor = by_id[cursor.parent_id]
      end
    end

    visible = records.select { |record| keep_ids.include?(record.id) }
    {
      selected_id: selected&.id,
      nodes: visible.map { |r|
        {
          id: r.id,
          name: r.name,
          level: r.level,
          parent_id: r.parent_id,
          active: r.active?
        }
      }
    }
  end

  private

  # Always re-resolve through the organization. Never trust an already-loaded
  # MerchandiseClass instance — it may belong to another organization.
  def coerce_merchandise_class(organization, selected)
    id = case selected
    when MerchandiseClass then selected.id
    when Integer, String then selected
    else
      return nil
    end

    organization.merchandise_classes.find_by(id: id)
  end
end
