# Workflow: Opening Stock via Inventory Adjustment

**Status:** Delivered in Phase 3  

**Type:** Record-level workflow  
**Governing:** ADR-0004, ADR-0006, ADR-0013; [architectural-locks](../implementation/architectural-locks.md); [receiving-and-inventory](../domains/receiving-and-inventory.md)  
**Open:** [OD-014](../implementation/open-decisions.md) for deficit allocation only (not required for ordinary opening from zero)

## Purpose

Establish sellable on-hand quantity (and opening valuation) **without** a purchase order or receipt. Used for opening balances, migration, and demonstration stock before Phase 5 receiving exists. Remains valid afterward for exceptional corrections and openings.

## Preconditions

- Store and organization active.
- Product variant exists with `inventory_tracking_mode = quantity`.
- User has `inventory.adjustment.create` and, for posting opening/quantity-only, `inventory.adjustment.post`.
- Cost-correction kind requires `inventory.cost_correction.post`, explicit reason, and full audit.
- Creating an opening draft that captures cost does not require `inventory.cost.view`.
- Viewing draft adjustment cost inputs is allowed for the creator or users with `inventory.adjustment.create`.
- Viewing posted adjustment cost history or existing stock valuation requires `inventory.cost.view`.


## Records read

- `product_variants`, classification defaults as needed
- `stock_balances` for store × variant (may not exist yet)

## Records created or changed

- `inventory_adjustments` / `inventory_adjustment_lines` (draft → posted)
- `inventory_ledger_entries`
- `stock_balances` quantity and valuation fields (`inventory_value_cents`, `moving_average_cost_cents`, `cost_quality`, …)
- Never edit `on_hand` except through ledger posting services

## Adjustment kinds

| Kind | Quantity | Cost behavior |
| --- | --- | --- |
| Opening inventory | Required | Actual, estimated (optional Department margin confirm), or unknown; from zero with known cost initializes aggregate value and average |
| Quantity-only | Required | Uses current moving average when positive and valued; must not arbitrarily rewrite valuation; crossing zero per Inventory Domain Phase 3 rules |
| Cost correction | Zero qty; requires `on_hand > 0` | Explicit valuation change; `inventory.cost_correction.post` + reason + audit |

## Transaction boundary

Draft save may be non-posting. **Post** runs in one DB transaction: validate → lock balance → write ledger → update balance → mark adjustment posted.

## Locks

- `stock_balances` row for store × variant (create under lock if missing)
- Optimistic `lock_version` (or equivalent) on the balance

## Status transitions

```text
draft → posted
draft → cancelled
```

Posted or cancelled adjustments (and their lines) are not edited or destroyed in place; corrections use new adjusting records. Draft updates lock the header and recheck status before replacing lines.


## Ledger / snapshot effects

Each posted line produces ledger entry fields at minimum: quantity delta, unit cost used, total value delta, adjustment type, reason, user, source adjustment line.

## Permissions and approvals

- Create draft: `inventory.adjustment.create`
- View draft cost inputs: creator or `inventory.adjustment.create`
- View posted cost history / stock valuation: `inventory.cost.view`
- Post opening/quantity-only: `inventory.adjustment.post`
- Post cost correction: `inventory.cost_correction.post` and `inventory.cost.view`, plus reason and audit
- No mandatory independent Approval in Phase 3


## Notes

- Unknown opening cost must never be stored or displayed as zero.
- Department estimate uses Inventory Domain formula; user must confirm; snapshots retained.
- Positive-balance cost corrections only in Phase 3; deficit-state corrections deferred with OD-014.

## Failure behavior

- Validation failure: no ledger, no balance change
- Lock conflict: retry or fail cleanly; no partial post
- Insufficient permission: abort

## Idempotency

Recommend an idempotency key on post for automated imports; interactive UI may rely on draft→posted single transition guard.

## Out of scope

- Receipts and PO linkage (Phase 5)
- Individual units (Phase 4d)
- Selling the stock (see POS workflows / Phase 4)

## Related workflows

- [quantity-tracked-sale.md](quantity-tracked-sale.md) (existing)
- [suspended-transaction.md](suspended-transaction.md) (existing)
- Future: opening-stock-to-sale integration narrative when Phase 4c lands
