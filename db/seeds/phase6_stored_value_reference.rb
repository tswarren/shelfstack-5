# frozen_string_literal: true

# Seed Phase 6 stored-value adjustment reasons.
# Tender type `stored_value` comes from docs/exports/tender_types.csv.
organization = Organization.first
raise "No organization found; run bin/rails shelfstack:bootstrap first" unless organization

reasons = [
  { code: "manual_correction", name: "Manual correction", requires_note: true, position: 10 },
  { code: "goodwill", name: "Goodwill", requires_note: true, position: 20 },
  { code: "migration", name: "Migration / opening balance", requires_note: false, position: 30 }
]

reasons.each do |attrs|
  reason = organization.stored_value_adjustment_reasons.find_or_initialize_by(code: attrs[:code])
  reason.name = attrs[:name]
  reason.requires_note = attrs[:requires_note]
  reason.position = attrs[:position]
  reason.active = true
  reason.save!
end

puts "Phase 6 stored-value reference seeded (adjustment reasons)"
