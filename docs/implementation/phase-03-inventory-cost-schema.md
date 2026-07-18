# Phase 3 — Inventory Cost Schema (Authoritative Subset)

**Status:** Authoritative for Phase 3 delivery  
**Governing:** [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md), [receiving-and-inventory](../domains/receiving-and-inventory.md)  
**Related:** Full exploratory design note in [design-notes/inventory-costing/inventory_cost_schema_design_note.md](design-notes/inventory-costing/inventory_cost_schema_design_note.md) (non-authoritative beyond this subset)

Reconcile these fields, constraints, and enums into schema documentation / proforma **before migrations**. Future deficit/variance structures remain exploratory under [OD-014](open-decisions.md).

## `stock_balances` fields

Forward-compatible minimum:

```text
inventory_value_cents                 nullable bigint
moving_average_cost_cents             nullable integer
cost_quality                          string, not null, default unknown
last_known_unit_cost_cents            nullable integer   # optional in Phase 3
last_known_cost_quality               nullable string    # optional in Phase 3
lock_version                          integer
```

## Constraints

```text
on_hand <= 0 → inventory_value_cents = 0; moving_average_cost_cents null
on_hand > 0 and cost_quality = unknown → inventory_value_cents null
on_hand > 0 and cost_quality != unknown → inventory_value_cents not null
explicit zero cost: inventory_value_cents = 0 and cost_quality != unknown
on_hand = 0 → cost_quality = unknown (current); last-known fields may retain history
unknown valued positive balance → inventory_value_delta_cents null on movements, not 0
```

Add `cost_quality` / method enums and check constraints for this Phase 3 subset to schema docs. Define an allowed-combination matrix before locking enums.

## Deferred (not Phase 3 required)

Deficit cache fields, variance tables, and settlement tables:

```text
deficit_costed_quantity
provisional_deficit_cost_cents
provisional_deficit_cost_quality
inventory_cost_variances
inventory_deficit_settlements   # only if origin-FIFO is chosen
```

Phase 3 may keep `inventory_value_cents = 0` when On Hand ≤ 0 without implementing full provisional-deficit reconciliation.

## Ledger entry cost fields (illustrative for Phase 3)

```text
quantity_delta
inventory_value_delta_cents
unit_cost_cents
movement_cost_cents
cost_method
cost_quality
resulting_on_hand
resulting_inventory_value_cents
source_type / source_id
reversal_of_entry_id
estimate snapshot fields when used
posting_key
posted_by_user_id
posted_at
reason
```

Whether `cost_finality` is a third enum or a boolean `provisional` remains open. Define an allowed-combination matrix before locking enums.

## Cost method and quality

Avoid mixing algorithm, storage model, and quality in one unclean enum. Candidate simplification:

```text
moving_average
exact_unit
original_snapshot
explicit
configured_estimate
retained_rate
unknown
```

Quality remains separate: `actual | estimated | mixed | unknown`.

## Persistence style

Prefer string columns with application validation and database check constraints over native PostgreSQL enums.
