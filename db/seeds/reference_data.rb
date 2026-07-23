# frozen_string_literal: true

# Organization-owned canonical masters. Requires an organization (bootstrap first).
# Invoked by: bin/rails shelfstack:seed_reference_data

organization = Organization.first
raise "No organization found; run bin/rails shelfstack:bootstrap first" unless organization

IdentifierSequence.ensure_defaults!
Classification::Import::ReferenceData.call(organization: organization)
load Rails.root.join("db/seeds/phase4b_store_tax.rb")
load Rails.root.join("db/seeds/phase6_stored_value_reference.rb")

puts "Reference data seed complete for organization=#{organization.code} " \
     "(identifier sequences ensured; classification masters imported from docs/exports; " \
     "demo store tax rates/rules seeded; Phase 6 stored-value reference seeded)"
