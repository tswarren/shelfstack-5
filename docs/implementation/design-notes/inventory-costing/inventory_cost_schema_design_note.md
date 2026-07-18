# Design note — inventory cost schema (proposed, not settled)

**Status:** Proposed design exploration  
**Authority:** Non-authoritative. The **Phase 3 subset** is authoritative in [phase-03-inventory-cost-schema.md](../../phase-03-inventory-cost-schema.md). Future deficit/variance structures remain exploratory under OD-014.

Related: [ADR-0013](../../../adr/0013-govern-quantity-tracked-inventory-cost.md), [receiving-and-inventory](../../../domains/receiving-and-inventory.md), [Phase 3 plan](../../phases/phase-03-quantity-inventory-bootstrap.md).

## Phase 3 candidate fields on `stock_balances`

Forward-compatible minimum:

```text
inventory_value_cents                 nullable bigint
moving_average_cost_cents             nullable integer
cost_quality                          string, not null, default unknown
last_known_unit_cost_cents            nullable integer   # optional in Phase 3
last_known_cost_quality               nullable string    # optional in Phase 3
lock_version                          integer
```

Suggested constraints:

```text
on_hand <= 0 → inventory_value_cents = 0; moving_average_cost_cents null
on_hand > 0 and cost_quality = unknown → inventory_value_cents null
on_hand > 0 and cost_quality != unknown → inventory_value_cents not null
explicit zero cost: inventory_value_cents = 0 and cost_quality != unknown
on_hand = 0 → cost_quality = unknown (current); last-known fields may retain history
unknown valued positive balance → inventory_value_delta_cents null on movements, not 0
```

Also add `cost_quality` / method enums and check constraints for the Phase 3 subset to schema docs on promotion. Define an allowed-combination matrix before locking enums.

## Deferred until a producer exists (not Phase 3 required)

Deficit cache fields, variance tables, and settlement tables:

```text
deficit_costed_quantity
provisional_deficit_cost_cents
provisional_deficit_cost_quality
inventory_cost_variances
inventory_deficit_settlements   # only if origin-FIFO is chosen
```

Phase 3 may keep `inventory_value_cents = 0` when On Hand ≤ 0 without implementing full provisional-deficit reconciliation.

## Ledger entry cost fields (illustrative)

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

## Illustrative cost_method values (needs cleanup)

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

## Deficit allocation alternatives (open)

### A — Aggregate proportional deficit pool

Fewer records; weaker per-origin Department attribution.

### B — Origin-FIFO settlement records

Requires durable `inventory_deficit_settlements` (or equivalent) for every allocation between incoming and deficit-origin movements, including unknown/zero variance cases. `inventory_cost_variances` would then represent monetary difference only.

Do not accept either alternative in ADR-0013 until the producer workflows exist and the data model is complete.

## Persistence style

Prefer string columns with application validation and database check constraints over native PostgreSQL enums.
