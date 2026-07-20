# OD-014 — Negative-Inventory Deficit Allocation and Settlement Representation

**Status:** accepted
**Needed by:** Phase 5 receipt posting
**Governing area:** Inventory / Receiving / POS / Reporting
**Related:** [ADR-0013](../../adr/0013-govern-quantity-tracked-inventory-cost.md); [Receiving and Inventory](../../domains/receiving-and-inventory.md); [Phase 5 Supply and Demand](../phases/phase-05-supply-and-demand.md)

### Decision

ShelfStack will use an aggregate Store-and-Variant deficit-cost pool rather than matching incoming inventory to individual deficit-creating sales.

Negative On Hand remains an aggregate inventory state.

ShelfStack does not persist origin-level allocations between incoming Receipt quantity and individual outbound Inventory Ledger Entries.

Instead, a Stock Balance with negative On Hand retains:

```text
open deficit quantity
open provisional deficit cost
deficit cost quality
```

Open deficit quantity is derived:

```text
open deficit quantity
=
max(-on_hand, 0)
```

Open provisional deficit cost is a non-asset memorandum balance representing the provisional cost already associated with the outstanding negative quantity.

It is not included in inventory asset value.

### Negative outbound posting

When an outbound quantity-tracked movement takes On Hand below zero or farther below zero, only the quantity that increases the deficit contributes to the open deficit-cost pool.

```text
deficit quantity created
=
max(-resulting on hand, 0)
− max(-prior on hand, 0)
```

The provisional cost attributable to that quantity is added to the aggregate open deficit-cost pool.

The completed POS Line and outbound Inventory Ledger Entry retain their provisional cost snapshots and are never rewritten when later inventory arrives.

### Receipt posting

Accepted Receipt quantity settles negative On Hand before creating positive inventory.

```text
deficit settlement quantity
=
min(
  accepted receipt quantity,
  max(-prior on hand, 0)
)
```

```text
positive inventory quantity
=
accepted receipt quantity
− deficit settlement quantity
```

A Receipt Line may create up to two Inventory Ledger Entries.

#### Deficit-settlement entry

The first entry:

```text
movement type: receipt_deficit_settlement
quantity delta: deficit settlement quantity
inventory value delta: zero
```

It:

* moves On Hand toward zero;
* creates no positive inventory asset;
* releases the proportional provisional deficit cost;
* records actual or estimated settlement cost;
* records cost variance or late cost recognition;
* reduces the aggregate open deficit-cost pool.

#### Positive-inventory entry

When accepted quantity remains after the deficit reaches zero, a second entry:

```text
movement type: receipt
quantity delta: positive inventory quantity
inventory value delta: acquisition cost of positive inventory quantity
```

It creates positive inventory and participates in the normal moving-weighted-average calculation.

The sum of both ledger-entry quantity deltas must equal accepted Receipt quantity.

### Partial settlement

When incoming quantity settles only part of the deficit, provisional cost is released proportionally:

```text
provisional cost released
=
round(
  open provisional deficit cost
  × deficit settlement quantity
  ÷ open deficit quantity before settlement
)
```

When the deficit is fully settled, the entire remaining provisional deficit-cost balance is released. This prevents residual rounding amounts.

### Known costs

When provisional and settlement costs are known:

```text
settlement variance
=
actual settlement cost
− provisional cost released
```

A positive variance is unfavorable.

A negative variance is favorable.

Variance is recognized as a separate non-quantity cost fact associated with the deficit-settlement ledger entry.

It does not change the original completed POS cost snapshot.

### Unknown provisional cost

Unknown provisional cost is not zero.

When provisional cost is unknown:

* provisional cost released remains null;
* known settlement cost is classified as late cost recognition;
* ordinary variance remains null;
* the original completed transaction remains unchanged.

### Unknown receipt cost

Receipt cost may use:

```text
actual Receipt cost
→ confirmed Vendor cost
→ Purchase-Order expected cost as an estimate
→ unknown
```

Cost quality must be retained.

Unknown receipt cost may settle physical deficit quantity, but its monetary effect remains explicitly unresolved until a later cost correction or settlement adjustment is posted.

### Inventory value

While On Hand is zero or negative:

```text
inventory asset value = zero
moving average cost = null
```

The open provisional deficit-cost pool is not an inventory asset.

Only Receipt quantity remaining after the deficit reaches zero creates positive inventory asset value.

### Returns and post-voids

Linked customer returns and post-voids use original completed cost.

When they move On Hand toward zero:

* they reduce open deficit quantity;
* they reduce the open provisional deficit-cost pool using the original cost;
* they do not create ordinary receipt cost variance.

### Quantity-only corrections

A quantity-only adjustment may move On Hand toward zero without providing acquisition cost.

It reduces deficit quantity.

Its treatment of the open provisional deficit-cost pool must be explicit and auditable. The baseline proportional release rule applies unless the correction is an exact reversal carrying an original known cost.

No acquisition cost is invented.

### Corrections

Posted deficit settlements are immutable.

Receipt or inventory corrections create reversing Inventory Ledger Entries that restore:

* quantity;
* positive inventory value;
* open provisional deficit cost;
* recorded variance or late cost recognition.

The original entries are not edited.

### Concurrency and idempotency

Receipt posting must atomically protect:

* the Stock Balance;
* the open deficit-cost pool;
* both generated Ledger Entries;
* inventory value;
* moving-average cost;
* Receipt posting status.

A Receipt Line posting key must prevent duplicate settlement and duplicate inventory creation during retry.

### Reporting

ShelfStack reports separately:

```text
provisional completed cost
deficit settlement cost
settlement variance
late cost recognition
positive inventory asset value
```

Completed transactions are not restated.

### Consequences

#### Benefits

* Avoids matching Receipts to individual historical sales.
* Requires no origin-allocation table.
* Supports partial deficit settlement.
* Preserves immutable completed sales.
* Keeps negative inventory asset value at zero.
* Produces deterministic variance calculations.
* Allows one Receipt Line to cross from negative to positive On Hand cleanly.
* Keeps receipt corrections auditable through reversing entries.

#### Costs

* Requires an aggregate provisional deficit-cost balance.
* Exact sale-level and Department-level variance attribution is not retained.
* Partial settlement uses proportional aggregate costing.
* Unknown-cost settlement requires later reconciliation.
* Receipt posting may create two Inventory Ledger Entries.

### Governing rules

* Negative inventory is maintained at Store-and-Variant level.
* Open deficit quantity is derived from negative On Hand.
* Open provisional deficit cost is an aggregate non-asset memorandum balance.
* Receipt quantity settles the deficit before creating positive inventory.
* One Receipt Line may produce a deficit-settlement entry and a positive-inventory entry.
* Deficit-settlement entries create no positive inventory value.
* Provisional deficit cost is released proportionally.
* Full settlement releases all residual provisional cost.
* Completed POS cost snapshots remain immutable.
* Unknown cost is never treated as zero.
* Cost variance is separate from inventory quantity.
* Corrections use reversing entries.
* Settlement posting is atomic and idempotent.

--

# Discussion

## Simpler aggregate model

When accepted receipt quantity encounters negative on-hand:

```text
deficit settlement quantity
=
min(accepted receipt quantity, absolute prior on_hand)

positive inventory quantity
=
accepted receipt quantity − deficit settlement quantity
```

One receipt line may create up to two inventory ledger entries:

```text
1. receipt_deficit_settlement
   Moves on_hand toward zero
   Creates no positive inventory asset
   Records the cost used to settle the deficit

2. receipt_inventory
   Represents any quantity remaining after the deficit reaches zero
   Creates positive inventory value normally
```

## Example

Before receipt:

```text
on_hand:                    -3
inventory value:            $0
provisional deficit cost:  $18
```

Receipt:

```text
accepted quantity:           5
actual unit cost:           $7
total receipt cost:        $35
```

### Entry 1 — settle the deficit

```text
movement_type: receipt_deficit_settlement
quantity_delta: +3

actual settlement cost:    $21
provisional deficit cost:  $18
variance:                   $3 unfavorable

resulting on_hand:           0
resulting inventory value:  $0
```

### Entry 2 — create positive inventory

```text
movement_type: receipt
quantity_delta: +2

inventory value delta:     $14

resulting on_hand:           2
resulting inventory value: $14
moving average cost:         $7
```

The ledger-entry quantities total the accepted receipt quantity:

```text
3 + 2 = 5
```

The receipt remains one operational Receipt Line. Its posting creates two inventory consequences.

## Why this is simpler

This avoids:

* matching receipts to individual negative sales;
* FIFO deficit-origin records;
* settlement-allocation tables;
* maintaining relationships between every incoming and outgoing movement;
* reconstructing partial origin settlements;
* department allocation across numerous historical sales.

Instead, ShelfStack maintains one aggregate deficit-cost state per Store and Variant.

## Aggregate deficit state

The quantity deficit is already visible from `on_hand`:

```text
deficit quantity = max(-on_hand, 0)
```

ShelfStack additionally needs to retain the aggregate provisional cost associated with that deficit.

That could be cached on `stock_balances`:

```text
deficit_provisional_cost_cents
deficit_cost_quality
```

Suggested quality values:

```text
actual
estimated
mixed
unknown
```

You might also name the value:

```text
open_deficit_cost_cents
```

This is not an inventory asset. It is a memorandum balance used to calculate later settlement variance.

## When a negative sale occurs

Assume:

```text
prior on_hand:      1
sale quantity:     -3
resulting on_hand: -2
```

Only two units create additional deficit.

If the provisional cost is $6 per unit:

```text
deficit quantity added:           2
deficit provisional cost added: $12
```

The stock balance becomes:

```text
on_hand:                         -2
inventory value:                 $0
open deficit provisional cost: $12
```

The completed POS line retains its normal provisional cost snapshot and is never changed later.

## When a receipt settles part of the deficit

Assume:

```text
on_hand before receipt:          -5
open provisional deficit cost:  $30

receipt quantity:                 2
receipt unit cost:               $7
```

The receipt settles two-fifths of the aggregate pool.

```text
provisional cost released
=
$30 × 2 / 5
=
$12
```

Actual settlement cost:

```text
2 × $7 = $14
```

Variance:

```text
$14 − $12 = $2 unfavorable
```

New balance:

```text
on_hand:                         -3
inventory value:                 $0
open provisional deficit cost: $18
```

No positive inventory entry is created because the receipt did not bring on-hand above zero.

## Proportional release from the pool

For partial settlement:

```text
released provisional cost
=
round(
  open provisional deficit cost
  × settled quantity
  ÷ deficit quantity before settlement
)
```

When the receipt fully resolves the deficit, release the entire remaining provisional pool. This prevents residual cents.

That is substantially simpler than matching each receipt to individual sales, while remaining deterministic.

## Monetary treatment

The deficit-settlement ledger entry should retain:

```text
settlement_quantity
provisional_cost_released_cents
actual_settlement_cost_cents
variance_cents
provisional_cost_quality
settlement_cost_quality
```

The entry’s quantity effect moves on-hand toward zero, but its inventory-value effect is zero.

The variance is a separate cost fact:

```text
positive variance
= actual cost exceeded provisional cost

negative variance
= actual cost was below provisional cost
```

It may be represented directly on the settlement ledger entry initially rather than introducing a separate variance table.

## Unknown provisional cost

When the deficit provisional cost is unknown:

```text
provisional_cost_released_cents = null
actual_settlement_cost_cents    = known receipt cost
variance_cents                  = null
variance_kind                   = late_cost_recognition
```

Unknown is not treated as zero.

## Unknown receipt cost

When the receipt cost is unknown:

```text
actual_settlement_cost_cents = null
variance_cents               = null
settlement_cost_quality      = unknown
```

The quantity can still settle the physical deficit.

The aggregate provisional deficit pool is reduced for the quantity settled, but the unresolved monetary treatment should remain reportable. A later explicit cost correction can resolve it without editing the receipt or completed sale.

## Returns and post-voids

A linked return or post-void that moves inventory back toward zero should also reduce the aggregate deficit pool.

Because it uses the original completed cost:

* the quantity settles part of the deficit;
* the corresponding original cost is removed from the deficit-cost pool;
* no acquisition-cost variance is created.

This is easier to handle than treating it as a vendor receipt.

## Corrections

If a posted receipt is reversed, reverse both generated ledger entries:

```text
receipt_deficit_settlement reversal
receipt_inventory reversal
```

The reversal restores:

* the prior on-hand balance;
* the prior positive inventory value;
* the prior open deficit provisional-cost pool;
* the prior variance position.

The two entries should share a receipt-line posting group or key so they can be reversed together.

## Recommended ledger behavior

| Situation                              | Ledger entries                                       |
| -------------------------------------- | ---------------------------------------------------- |
| Receipt while on-hand positive or zero | One ordinary `receipt` entry                         |
| Receipt smaller than deficit           | One `receipt_deficit_settlement` entry               |
| Receipt exactly equals deficit         | One `receipt_deficit_settlement` entry               |
| Receipt exceeds deficit                | One settlement entry plus one ordinary receipt entry |




This is a better Phase 5 baseline than origin-level FIFO matching. It preserves the accounting distinctions ShelfStack needs while avoiding a large settlement subsystem.
