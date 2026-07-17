# Workflow: Opening Stock via Inventory Adjustment

**Status:** Delivery Phase 3  
**Type:** Record-level workflow  
**Governing:** ADR-0004, ADR-0006; [architectural-locks](../implementation/architectural-locks.md); [receiving-and-inventory](../domains/receiving-and-inventory.md)  
**Open:** [OD-003](../implementation/open-decisions.md) costing formulas for zero/negative on-hand

## Purpose

Establish sellable on-hand quantity (and opening valuation) **without** a purchase order or receipt. Used for opening balances, migration, and demonstration stock before Phase 5 receiving exists. Remains valid afterward for exceptional corrections and openings.

## Preconditions

- Store and organization active.
- Product variant exists with `inventory_tracking_mode = quantity`.
- User has `inventory.adjustment.create` and, for posting, `inventory.adjustment.post`.
- Cost-correction kind requires elevated permission/authority per policy.

## Records read

- `product_variants`, classification defaults as needed
- `stock_balances` for store × variant (may not exist yet)

## Records created or changed

- `inventory_adjustments` / `inventory_adjustment_lines` (draft → posted)
- `inventory_ledger_entries`
- `stock_balances.on_hand` (and valuation fields per OD-003)
- Never edit `on_hand` except through ledger posting services

## Adjustment kinds

| Kind | Quantity | Cost behavior |
| --- | --- | --- |
| Opening inventory | Required | Explicit opening unit cost; initializes/updates value per OD-003 |
| Quantity-only | Required | Uses **current** moving-average cost; must not arbitrarily rewrite valuation |
| Cost correction | Usually zero qty | Explicit valuation change; elevated permission + reason |

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

Posted adjustments are not edited in place; corrections use new adjusting records.

## Ledger / snapshot effects

Each posted line produces ledger entry fields at minimum: quantity delta, unit cost used, total value delta, adjustment type, reason, user, source adjustment line.

## Permissions and approvals

- Create draft: `inventory.adjustment.create`
- Post: `inventory.adjustment.post`
- Cost correction may require approval when authority insufficient

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
