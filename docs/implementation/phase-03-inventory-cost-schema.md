# Phase 3 — Inventory Cost Schema (Authoritative Subset)

**Status:** Implemented (Phase 3 complete); authoritative field notes for quantity-tracked costing  

**Governing:** [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md), [receiving-and-inventory](../domains/receiving-and-inventory.md)  
**Related:** Full exploratory design note in [design-notes/inventory-costing/inventory_cost_schema_design_note.md](design-notes/inventory-costing/inventory_cost_schema_design_note.md) (non-authoritative beyond this subset)

Reconcile these fields, constraints, and enums into schema documentation / proforma **before migrations**. Future deficit/variance structures remain exploratory under [OD-014](open-decisions.md).

## Principal tables

```text
stock_balances
inventory_ledger_entries
inventory_reservations
inventory_adjustments
inventory_adjustment_lines
inventory_adjustment_reasons
```

Plus `departments.default_cost_estimation_margin_bps`.

## `stock_balances` fields

```text
store_id                              FK stores, null: false
product_variant_id                    FK product_variants, null: false
on_hand                               integer, not null, default 0
reserved                              integer, not null, default 0
unavailable                           integer, not null, default 0
inventory_value_cents                 nullable bigint
moving_average_cost_cents             nullable integer
cost_quality                          string, not null, default unknown
last_known_unit_cost_cents            nullable integer
last_known_cost_quality               nullable string
lock_version                          integer, not null, default 0
timestamps
```

Unique `(store_id, product_variant_id)`.

`on_order` is deferred until Purchasing/Receiving.

## Constraints

```text
on_hand <= 0 → inventory_value_cents = 0; moving_average_cost_cents null
on_hand > 0 and cost_quality = unknown → inventory_value_cents null
on_hand > 0 and cost_quality != unknown → inventory_value_cents not null
explicit zero cost: inventory_value_cents = 0 and cost_quality != unknown
on_hand = 0 → cost_quality = unknown (current); last-known fields may retain history
unknown valued positive balance → inventory_value_delta_cents null on movements, not 0
reserved >= 0; unavailable >= 0
```

`last_known_unit_cost_cents` / `last_known_cost_quality` update whenever a posted movement leaves `on_hand > 0` with a known carrying average (including quantity-only moves that change the average via rounding). When On Hand reaches zero or below, leave last-known unchanged so a defensible pre-zero rate remains available for later retained-cost policy.


## `inventory_ledger_entries` fields

```text
store_id
product_variant_id
movement_type                         opening_inventory | quantity_adjustment | cost_correction (+ later)
quantity_delta                        signed integer, not null
inventory_value_delta_cents           signed bigint, nullable (null = unknown delta)
movement_cost_cents                   nonnegative integer, nullable
unit_cost_cents                       nonnegative integer, nullable
cost_method                           explicit | configured_estimate | moving_average | unknown
cost_quality                          actual | estimated | mixed | unknown
resulting_on_hand
resulting_inventory_value_cents
resulting_moving_average_cost_cents
resulting_cost_quality
reason_code                           qualified reason snapshot (e.g. quantity_only.physical_count_shortage)
reason_note                           optional free-text note (not concatenated into reason_code)
source_type / source_id               polymorphic
reversal_of_entry_id                  nullable FK
estimate_department_id
estimate_regular_price_cents
estimate_margin_bps
estimate_unit_cost_cents
posting_key                           unique global string
posted_by_user_id
posted_at
created_at
```

Phase 3 emitted `cost_method` values: `explicit`, `configured_estimate`, `moving_average`, `unknown` only (`retained_rate` reserved).

**Cost correction ledger:**

```text
quantity_delta = 0
inventory_value_delta_cents = corrected_inventory_value_cents - prior inventory_value_cents
movement_cost_cents = null
```

## `inventory_reservations` fields

```text
store_id
product_variant_id
source_type / source_id               polymorphic (pos_line_item | product_request)
quantity                              integer > 0 while active
status                                active | released | converted
reserved_at
released_at
converted_at
released_by_user_id
release_reason
timestamps
```

Partial unique index:

```sql
UNIQUE (store_id, product_variant_id, source_type, source_id)
WHERE status = 'active'
```

## `inventory_adjustment_reasons`

```text
organization_id
adjustment_kind                       opening_inventory | quantity_only | cost_correction
code                                  immutable after create
name
description
requires_note
active
position
timestamps
```

Unique `(organization_id, adjustment_kind, code)`. Derived `qualified_code = "#{kind}.#{code}"` (not stored).

## `inventory_adjustments`

```text
store_id
kind                                  opening_inventory | quantity_only | cost_correction
status                                draft | posted | cancelled
inventory_adjustment_reason_id
note                                  optional in draft; required at post when reason.requires_note
reason_code_snapshot                  set on post
reason_name_snapshot                  set on post
created_by_user_id
posted_by_user_id / posted_at
cancelled_by_user_id / cancelled_at / cancel_note
posting_key                           generated at start of post; reused on retry
timestamps
```

Derive `qualified_reason_code` as `"#{kind}.#{reason_code_snapshot}"`.

## `inventory_adjustment_lines`

```text
inventory_adjustment_id
product_variant_id                    UNIQUE per adjustment
position
quantity_delta
input_unit_cost_cents                 opening input
input_cost_method
input_cost_quality
corrected_inventory_value_cents       cost_correction aggregate input
estimate_department_id
estimate_regular_price_cents
estimate_margin_bps
estimate_unit_cost_cents
timestamps
```

| Adjustment kind     | Cost input                                         |
| ------------------- | -------------------------------------------------- |
| `opening_inventory` | `input_unit_cost_cents` / configured estimate / unknown |
| `quantity_only`     | No replacement cost input                          |
| `cost_correction`   | `corrected_inventory_value_cents` + quality/method |

## Cost method and quality

```text
cost_method:  explicit | configured_estimate | moving_average | unknown | (retained_rate reserved)
cost_quality: actual | estimated | mixed | unknown
```

Prefer string columns with application validation and database check constraints over native PostgreSQL enums.

## Deferred (not Phase 3 required)

```text
deficit_costed_quantity
provisional_deficit_cost_cents
provisional_deficit_cost_quality
inventory_cost_variances
inventory_deficit_settlements
```

Phase 3 may keep `inventory_value_cents = 0` when On Hand ≤ 0 without implementing full provisional-deficit reconciliation.
