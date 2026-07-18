#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates docs/exports/merchandise_classes.csv from source leaf dumps.
# Usage: ruby script/build_merchandise_classes.rb

require "csv"
require "set"

ROOT = File.expand_path("..", __dir__)
SOURCES = File.join(ROOT, "docs/exports/sources")
OUTPUT = File.join(ROOT, "docs/exports/merchandise_classes.csv")
DEPARTMENTS = File.join(ROOT, "docs/exports/departments.csv")
OVERRIDES = File.join(SOURCES, "merchandise_class_default_overrides.csv")

def parse_dept(value)
  return nil if value.nil? || value.strip.empty?

  value.strip.split(":", 2).first.strip
end

def load_postable_departments
  postable = {}
  CSV.foreach(DEPARTMENTS, headers: true) do |row|
    postable[row["department_number"]] = row["postable"].to_s.upcase == "TRUE"
  end
  postable
end

def blank_to_nil(value)
  return nil if value.nil?

  stripped = value.to_s.strip
  stripped.empty? ? nil : stripped
end

def load_overrides
  return {} unless File.exist?(OVERRIDES)

  CSV.foreach(OVERRIDES, headers: true).each_with_object({}) do |row, hash|
    hash[row["code"]] = {
      default_department_number: blank_to_nil(row["default_department_number"]),
      default_used_department_number: blank_to_nil(row["default_used_department_number"]),
      clear_used: row.key?("default_used_department_number")
    }
  end
end

leaves = []
CSV.foreach(File.join(SOURCES, "merchandise_categories_leaf.csv"), headers: true) do |row|
  leaves << {
    primary: row["Primary"],
    secondary: row["Secondary"],
    minor: row["Minor"],
    primary_code: row["primary_code"],
    secondary_code: row["secondary_code"],
    minor_code: row["minor_code"],
    default_department_number: parse_dept(row["default_department"]),
    default_used_department_number: parse_dept(row["default used department"])
  }
end

sort_by_path = {}
CSV.foreach(File.join(SOURCES, "merchandise_classes_leaf_sort.csv"), headers: true) do |row|
  key = [ row["Primary"], row["Secondary"], row["Minor"] ]
  sort_by_path[key] = row["Original Sort"].to_i
end

leaves.each do |leaf|
  key = [ leaf[:primary], leaf[:secondary], leaf[:minor] ]
  leaf[:sort] = sort_by_path.fetch(key) do
    warn "Missing sort for #{key.inspect}; using 999999"
    999_999
  end
end

nodes = {}

leaves.each do |leaf|
  p_code = leaf[:primary_code]
  s_code = "#{p_code}.#{leaf[:secondary_code]}"
  m_code = "#{s_code}.#{leaf[:minor_code]}"

  nodes[p_code] ||= {
    code: p_code,
    parent_code: nil,
    level: "primary",
    name: leaf[:primary],
    sorts: [],
    defaults: [],
    used_defaults: []
  }
  nodes[s_code] ||= {
    code: s_code,
    parent_code: p_code,
    level: "secondary",
    name: leaf[:secondary],
    sorts: [],
    defaults: [],
    used_defaults: []
  }
  nodes[m_code] = {
    code: m_code,
    parent_code: s_code,
    level: "minor",
    name: leaf[:minor],
    sorts: [ leaf[:sort] ],
    defaults: [ leaf[:default_department_number] ],
    used_defaults: [ leaf[:default_used_department_number] ],
    default_department_number: leaf[:default_department_number],
    default_used_department_number: leaf[:default_used_department_number]
  }

  nodes[p_code][:sorts] << leaf[:sort]
  nodes[s_code][:sorts] << leaf[:sort]
  nodes[p_code][:defaults] << leaf[:default_department_number]
  nodes[s_code][:defaults] << leaf[:default_department_number]
  nodes[p_code][:used_defaults] << leaf[:default_used_department_number]
  nodes[s_code][:used_defaults] << leaf[:default_used_department_number]
end

def resolve_common(values, label, code)
  compact = values.compact.uniq
  return nil if compact.empty?
  return compact.first if compact.size == 1

  :conflict
end

overrides = load_overrides
conflicts = []

nodes.each_value do |node|
  next if node[:level] == "minor"

  default = resolve_common(node[:defaults], "default", node[:code])
  used = resolve_common(node[:used_defaults], "used", node[:code])

  if default == :conflict
    if overrides.dig(node[:code], :default_department_number)
      default = overrides[node[:code]][:default_department_number]
    else
      conflicts << [ node[:code], "default_department_number", node[:defaults].compact.uniq ]
      default = nil
    end
  end

  if used == :conflict
    if overrides.key?(node[:code]) && overrides[node[:code]].key?(:default_used_department_number)
      used = overrides[node[:code]][:default_used_department_number]
    else
      conflicts << [ node[:code], "default_used_department_number", node[:used_defaults].compact.uniq ]
      used = nil
    end
  end

  if overrides[node[:code]]
    default = overrides[node[:code]][:default_department_number] if overrides[node[:code]][:default_department_number]
    if overrides[node[:code]].key?(:default_used_department_number)
      used = overrides[node[:code]][:default_used_department_number]
    end
  end

  node[:default_department_number] = default
  node[:default_used_department_number] = used
  node[:position] = node[:sorts].min
end

nodes.each_value do |node|
  next unless node[:level] == "minor"

  node[:position] = node[:sorts].min
end

if conflicts.any?
  warn "Department default conflicts (add rows to merchandise_class_default_overrides.csv):"
  conflicts.uniq.each do |code, field, values|
    warn "  #{code} #{field}: #{values.inspect}"
  end
  exit 1
end

postable = load_postable_departments
errors = []

nodes.each_value do |node|
  dept = node[:default_department_number]
  if dept.nil?
    errors << "#{node[:code]} missing default_department_number"
    next
  end
  unless postable.key?(dept)
    errors << "#{node[:code]} unknown department #{dept}"
  end
  if postable.key?(dept) && !postable[dept]
    errors << "#{node[:code]} default department #{dept} is not postable"
  end

  used = node[:default_used_department_number]
  next if used.nil?

  unless postable.key?(used)
    errors << "#{node[:code]} unknown used department #{used}"
  end
  if postable.key?(used) && !postable[used]
    errors << "#{node[:code]} used department #{used} is not postable"
  end
end

if errors.any?
  warn "Validation errors:"
  errors.each { |e| warn "  #{e}" }
  exit 1
end

ordered = nodes.values.sort_by { |n| [ n[:position], n[:level] == "primary" ? 0 : n[:level] == "secondary" ? 1 : 2, n[:code] ] }

CSV.open(OUTPUT, "w") do |csv|
  csv << %w[
    code parent_code level name position
    default_department_number default_used_department_number
  ]
  ordered.each do |node|
    csv << [
      node[:code],
      node[:parent_code],
      node[:level],
      node[:name],
      node[:position],
      node[:default_department_number],
      node[:default_used_department_number]
    ]
  end
end

puts "Wrote #{ordered.size} merchandise class nodes to #{OUTPUT}"
