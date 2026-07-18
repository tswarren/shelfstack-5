# frozen_string_literal: true

# Organization-owned canonical masters. Requires an organization (bootstrap first).
# Invoked by: bin/rails shelfstack:seed_reference_data

organization = Organization.first
raise "No organization found; run bin/rails shelfstack:bootstrap first" unless organization

IdentifierSequence.ensure_defaults!
Classification::Import::ReferenceData.call(organization: organization)

puts "Reference data seed complete for organization=#{organization.code} " \
     "(identifier sequences ensured; classification masters imported from docs/exports)"
