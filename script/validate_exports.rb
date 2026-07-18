#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "set"

ROOT = File.expand_path("..", __dir__)
EXPORTS = File.join(ROOT, "docs/exports")
errors = []

def load_csv(path)
  CSV.read(path, headers: true)
end

taxes = load_csv(File.join(EXPORTS, "tax_categories.csv"))
tax_codes = taxes.map { |r| r["code"] }
errors << "duplicate tax codes" unless tax_codes.uniq.size == tax_codes.size

depts = load_csv(File.join(EXPORTS, "departments.csv"))
dept_numbers = depts.map { |r| r["department_number"] }
dept_codes = depts.map { |r| r["code"] }
errors << "duplicate department numbers" unless dept_numbers.uniq.size == dept_numbers.size
errors << "duplicate department codes" unless dept_codes.uniq.size == dept_codes.size

postable = {}
depts.each do |r|
  postable[r["department_number"]] = r["postable"].to_s.upcase == "TRUE"
  parent = r["parent_department_number"]
  if parent && !parent.empty? && !dept_numbers.include?(parent)
    errors << "department #{r["department_number"]} unknown parent #{parent}"
  end
  tax = r["tax_category_code"]
  if postable[r["department_number"]]
    if tax.nil? || tax.empty?
      errors << "posting department #{r["department_number"]} missing tax_category_code"
    elsif !tax_codes.include?(tax)
      errors << "department #{r["department_number"]} unknown tax #{tax}"
    end
    if (r["sales_revenue_gl_account_code"].nil? || r["sales_revenue_gl_account_code"].empty?) &&
       r["department_number"] != "710" # admissions may omit inventory asset
      # require at least sales revenue for posting
      errors << "posting department #{r["department_number"]} missing sales_revenue_gl_account_code" if r["sales_revenue_gl_account_code"].to_s.empty?
    end
  end
end

policies = load_csv(File.join(EXPORTS, "return_policies.csv")).map { |r| r["code"] }
discounts = load_csv(File.join(EXPORTS, "discount_reasons.csv"))
allowed_methods = %w[percentage fixed_amount fixed_price]
discounts.each do |r|
  method = r["default_calculation_method"]
  if method && !method.empty? && !allowed_methods.include?(method)
    errors << "discount #{r["code"]} invalid method #{method}"
  end
  pol = r["resulting_return_policy_code"]
  if pol && !pol.empty? && !policies.include?(pol)
    errors << "discount #{r["code"]} unknown policy #{pol}"
  end
  if r["requires_approval"].to_s.empty?
    errors << "discount #{r["code"]} blank requires_approval"
  end
end

reasons = load_csv(File.join(EXPORTS, "return_reasons.csv")).map { |r| r["code"] }
errors << "duplicate return reasons" unless reasons.uniq.size == reasons.size

formats = load_csv(File.join(EXPORTS, "product_formats.csv"))
format_codes = formats.map { |r| r["code"] }
errors << "duplicate format codes" unless format_codes.uniq.size == format_codes.size
formats.each do |r|
  if r["format_family"].to_s.include?(",")
    errors << "format #{r["code"]} has multi family"
  end
  if r["name"] =~ /digital/i || %w[ebook digital_music digital_video].include?(r["code"])
    errors << "format #{r["code"]} should track none" unless r["default_inventory_tracking_mode"] == "none"
  end
end

classes = load_csv(File.join(EXPORTS, "merchandise_classes.csv"))
class_codes = classes.map { |r| r["code"] }
errors << "duplicate class codes" unless class_codes.uniq.size == class_codes.size
code_set = class_codes.to_set
classes.each do |r|
  unless %w[primary secondary minor].include?(r["level"])
    errors << "class #{r["code"]} bad level #{r["level"]}"
  end
  parent = r["parent_code"]
  if parent && !parent.empty? && !code_set.include?(parent)
    errors << "class #{r["code"]} unknown parent #{parent}"
  end
  dept = r["default_department_number"]
  errors << "class #{r["code"]} missing default dept" if dept.nil? || dept.empty?
  errors << "class #{r["code"]} unknown dept #{dept}" if dept && !dept.empty? && !postable.key?(dept)
  errors << "class #{r["code"]} nonpostable default dept #{dept}" if dept && postable[dept] == false
  used = r["default_used_department_number"]
  if used && !used.empty?
    errors << "class #{r["code"]} unknown used dept #{used}" unless postable.key?(used)
    errors << "class #{r["code"]} nonpostable used dept #{used}" if postable[used] == false
  end
end

if errors.empty?
  puts "OK: exports validation passed (#{depts.size} departments, #{classes.size} merchandise classes, #{formats.size} formats)"
  exit 0
end

warn "FAILED:"
errors.each { |e| warn "  #{e}" }
exit 1
