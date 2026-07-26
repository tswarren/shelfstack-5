# frozen_string_literal: true

module MerchandiseClassFormHelper
  # Flat hierarchical options for the canonical merchandise-class select.
  # Includes the selected record and its ancestors even when inactive.
  def merchandise_class_select_options(organization, selected: nil)
    selected = coerce_merchandise_class(organization, selected)
    records = organization.merchandise_classes.includes(:parent).to_a
    keep_ids = Set.new(records.select(&:active?).map(&:id))
    if selected
      cursor = selected
      while cursor
        keep_ids << cursor.id
        cursor = cursor.parent
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
    keep_ids = Set.new(records.select(&:active?).map(&:id))
    if selected
      cursor = selected
      while cursor
        keep_ids << cursor.id
        cursor = records.find { |r| r.id == cursor.parent_id } || cursor.parent
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

  def coerce_merchandise_class(organization, selected)
    case selected
    when MerchandiseClass then selected
    when Integer, String
      organization.merchandise_classes.find_by(id: selected)
    else
      nil
    end
  end
end
