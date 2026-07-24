# ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections

**Status:** Accepted

## Context

Retail systems must preserve reliable historical records for:

* sales;  
* returns;  
* tax;  
* tenders;  
* inventory;  
* stored value;  
* cost;  
* cash accountability;  
* audit.

Changing a completed transaction or line in place would obscure what originally occurred.

Earlier schema concepts included:

* transaction status `voided`;  
* line status `returned`;  
* mutation timestamps such as `voided_at` or `returned_at`.

These conflict with the requirement that completed facts remain reproducible.

## Decision

Completed POS transactions and their completed lines will be immutable.

A POS transaction may have one of the following statuses:

```
open
suspended
completed
cancelled
```

A completed transaction never changes to another status.

## Pre-completion cancellation

An open transaction may be cancelled.

Cancellation:

* releases reservations;  
* removes provisional discounts;  
* removes provisional tax;  
* resolves provisional tender activity;  
* cancels provisional stored-value activity;  
* creates no completed sale;  
* creates no inventory movement;  
* creates no completed tender;  
* creates no receipt number.

## Pending-line removal

A pending line may be removed before transaction completion.

The line is retained with status:

```
removed
```

Removal:

* releases its reservation;  
* excludes it from totals;  
* excludes it from promotion qualification;  
* creates no completed commercial effect.

## Customer return

A return is represented by a new return line.

The new line may reference the original completed sale line.

The original line remains unchanged.

A linked return reverses the applicable original:

* quantity;  
* selling amount;  
* discount allocation;  
* tax;  
* cost;  
* department;  
* inventory effect.

## Post-void

A post-void is a new completed transaction that fully reverses a prior completed transaction.

The reversing transaction:

* receives its own receipt number;  
* references the original transaction;  
* reverses each original line;  
* reverses each original tender;  
* reverses inventory;  
* reverses tax;  
* reverses cost;  
* reverses stored value;  
* uses original historical values rather than current configuration.

A post-void may be blocked when complete reversal is no longer possible.

Examples include:

* part of the original has already been returned;  
* a tender has already been partially refunded;  
* issued stored value has already been redeemed;  
* an exact inventory unit has subsequently been sold;  
* the transaction has already been post-voided.

## Reconciliation records

Reconciliation documents differences between ShelfStack expected totals and counted or external evidence through comparisons, findings, and resolutions (Phase 7).

Those records do not rewrite the original completed transaction or tender, and they do not act as a generic balance-changing ledger. Operational corrections use owning-domain reversing or adjusting records and may be linked from a reconciliation resolution.

## Consequences

### Benefits

* Preserves complete audit history.  
* Makes historical reporting reproducible.  
* Supports exact reversal of tax, inventory, cost, and stored value.  
* Prevents hidden manipulation of completed records.  
* Distinguishes customer returns from administrative reversals.

### Costs

* Corrections create additional records.  
* Reports must understand reversal relationships.  
* User interfaces must display original and corrective activity together.  
* Some post-voids must be blocked after downstream activity.

## Alternatives considered

### Change completed transactions to `voided`

Rejected because the original completed state would be lost.

### Mark original sale lines as returned

Rejected because a return is a separate commercial event occurring later.

### Edit incorrect completed tenders or tax amounts

Rejected because reconciliation and audit require preservation of the original record.

## Governing rules

* A completed transaction is never edited or deleted.  
* A completed line is never changed to returned or voided.  
* Returns create new return lines.  
* Post-voids create new complete reversing transactions.  
* Corrective records retain references to original records.  
* Current product, tax, price, or cost rules are not used to recalculate a historical reversal.

## Related domains

* Point of Sale  
* Receiving and Inventory  
* Stored Value  
* Reporting and Reconciliation