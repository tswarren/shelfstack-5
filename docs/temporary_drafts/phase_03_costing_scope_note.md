# Phase 3 scoping note for ADR-0013 dispositions

**Status:** Draft companion to Phase 3  
**Related:** [phase-03-quantity-inventory-bootstrap.md](../implementation/phases/phase-03-quantity-inventory-bootstrap.md), [ADR-0013 draft](0013-govern-quantity-tracked-inventory-cost.md)

## Intent

Accept ADR-0013 costing rules before or with Phase 3. Implement only the Phase 3 slice; document later workflow costing without building those workflows.

## Add to Phase 3 governing docs

* ADR-0013 (once accepted)
* Inventory domain cost sections from the domain update draft
* Permission catalog cost-correction keys

## Principal tables (revised)

Keep:

* `stock_balances`
* `inventory_ledger_entries`
* `inventory_reservations`
* `inventory_adjustments`
* `inventory_adjustment_lines`

Add for Phase 3 if negative On Hand or cost corrections can create variances before Receipts:

* `inventory_cost_variances`

## Stock Balance fields in Phase 3

Implement ADR-0013 current-state cache fields:

* `inventory_value_cents`
* `moving_average_cost_cents`
* `cost_quality`
* `last_known_unit_cost_cents`
* `last_known_cost_quality`
* `deficit_costed_quantity`
* `provisional_deficit_cost_cents`
* `provisional_deficit_cost_quality`
* lock version

## Classification fields in Phase 3

* optional `default_cost_estimation_margin_bps` on departments
* `inventory_deficit_clearing_gl_account_code`
* `inventory_cost_variance_gl_account_code`

Store-level estimation policy table: **not** Phase 3.

## Document only in Phase 3 (do not implement workflows)

* Transfer costing rules
* RTV costing rules
* Count costing rules
* Receipt-correction counterfactual replay

## Exit criteria additions

* Posted opening adjustment establishes quantity and actual, estimated, or unknown cost correctly
* Quantity-only adjustment does not arbitrarily rewrite valuation
* Cost correction posts only with `inventory.cost_correction.post` (+ authority/Approval when required)
* Negative On Hand keeps `inventory_value_cents = 0` and retains provisional deficit cache when applicable
* Ledger explains quantity and value deltas; balance remains reconcilable
* Unknown cost is never treated or displayed as zero

## Close when promoting docs

* OD-003 → accepted, citing ADR-0013
* Remove Inventory domain open question on negative On Hand moving average
* Index ADR-0013 in `docs/adr/README.md`
