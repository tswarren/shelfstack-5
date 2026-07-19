# frozen_string_literal: true

# Phase 4b transaction-scoped Tax Exemption. Coverage is restricted to
# `whole_transaction`; selected-line / selected-component coverage remains deferred
# (see docs/implementation/phase-04-tax-schema.md). Distinct from a Store Tax Rule
# with treatment "exempt": this records why an otherwise rule-taxable transaction was
# exempted for this specific sale.
class PosTaxExemption < ApplicationRecord
  COVERAGES = %w[whole_transaction].freeze

  belongs_to :pos_transaction
  belongs_to :created_by_user, class_name: "User"

  validates :coverage, presence: true, inclusion: { in: COVERAGES }
  validates :exemption_type, presence: true
end
