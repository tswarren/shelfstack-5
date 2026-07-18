# Phase 3 costing scope note

**Status:** Draft companion to Phase 3  
**Related:** [phase-03-quantity-inventory-bootstrap.md](../implementation/phases/phase-03-quantity-inventory-bootstrap.md), [ADR-0013 draft](0013-govern-quantity-tracked-inventory-cost.md)

Phase 3 remains intentionally narrow: balances, ledger posting, reservations, adjustments, and opening stock **without** purchasing or Receipts.

## Required Phase 3 behavior

* `inventory_value_cents` on Stock Balance
* cached `moving_average_cost_cents`
* basic `cost_quality`
* opening inventory with actual, estimated, or unknown cost
* quantity-only adjustments that do not arbitrarily rewrite valuation
* explicit positive-balance cost corrections
* ledger quantity and value deltas
* deterministic rounding
* concurrency and value reconciliation
* when On Hand ≤ 0, positive inventory asset value is zero
* unknown cost never treated as zero
* optional `last_known_unit_cost_*` if useful for later negative-sale provisional COGS

## Permissions in Phase 3

* `inventory.adjustment.post` for opening / quantity-only
* `inventory.cost_correction.post` + Approval for cost corrections
* numeric correction authority deferred (see permission draft)

## Classification in Phase 3

* optional `default_cost_estimation_margin_bps` when estimate path is implemented
* **no** deficit-clearing or cost-variance GL fields

## Future-compatible, not implemented in Phase 3

* provisional COGS from POS negative sales (Phase 4c)
* deficit settlement from Receipts (Phase 5)
* `inventory_cost_variances` / settlement tables
* FIFO or proportional deficit allocation
* accounting clearing / export journals
* Receipt-correction allocation
* transfer / RTV / count workflows

## Principal tables

Keep Phase 3 list:

* `stock_balances`
* `inventory_ledger_entries`
* `inventory_reservations`
* `inventory_adjustments`
* `inventory_adjustment_lines`

Do **not** require `inventory_cost_variances` for Phase 3 exit.

## Exit criteria additions

* Posted opening adjustment creates sellable on-hand with correct cost quality / value
* Quantity-only adjustment does not arbitrarily rewrite valuation
* Positive cost correction posts only via cost-correction permission + Approval
* Negative On Hand keeps inventory asset value at zero
* Ledger explains quantity and value deltas; balance reconcilable
* Unknown cost is never treated as zero
* No receipt tables in schema

## On ADR acceptance

* Index ADR-0013 in `docs/adr/README.md`
* Close OD-003 citing ADR-0013
* Apply Inventory domain cost sections (not the design-note companions)
* Apply slim Catalog / Classification / permission patches
* Update this note into Phase 3 governing docs
