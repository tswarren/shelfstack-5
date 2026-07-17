# ADR-0009: Complete POS Transactions Atomically and Idempotently

**Status:** Accepted

## Context

Completing a POS transaction affects several domains:

* transaction status;  
* line amounts;  
* discounts;  
* tax;  
* tenders;  
* inventory reservations;  
* inventory balances;  
* inventory units;  
* cost;  
* stored value;  
* receipt numbering.

A partial failure could otherwise produce serious inconsistencies, such as:

* payment recorded without a completed sale;  
* inventory reduced without a receipt;  
* gift card issued without payment;  
* transaction completed twice;  
* receipt number consumed for a failed transaction.

Network retries and repeated cashier actions also create a risk of duplicate completion.

## Decision

POS completion will be one atomic and idempotent operation.

All required internal effects must commit together or none may commit.

## Pre-completion validation

Before commit, ShelfStack validates:

* transaction is open;  
* active store is valid;  
* business day is open;  
* completion session is open;  
* product and variant remain sellable;  
* exact inventory units are selected where required;  
* reservations remain valid;  
* prices resolve;  
* departments resolve;  
* tax categories resolve;  
* discounts and promotions are valid;  
* return approvals are satisfied;  
* return dispositions are valid;  
* tenders settle the transaction;  
* stored-value balances are sufficient;  
* standalone card approvals are confirmed;  
* the idempotency key has not already completed another operation.

## Atomic commit

Within one database transaction, ShelfStack will:

1. lock the POS transaction;  
2. lock affected inventory records;  
3. lock affected stored-value records;  
4. finalize line values;  
5. finalize discount allocations;  
6. finalize tax components;  
7. snapshot classifications and cost;  
8. convert inventory reservations;  
9. post inventory movements;  
10. update inventory-unit statuses;  
11. post stored-value entries;  
12. finalize tenders;  
13. obtain the next store receipt sequence;  
14. assign the receipt number;  
15. mark lines completed;  
16. mark the transaction completed;  
17. store final totals;  
18. commit.

If any required step fails before commit, none of the internal effects remain posted.

## Idempotency

Each completion request will contain a unique idempotency key.

Repeating a completion request with the same key must:

* return the already completed result; or  
* safely report that the operation is already in progress or complete.

It must not create duplicate:

* receipts;  
* inventory movements;  
* stored-value entries;  
* tenders;  
* completed transactions.

## Standalone payment terminal limitation

The initial card workflow uses standalone terminals.

ShelfStack cannot make the external terminal transaction part of its internal database transaction.

Therefore:

* external approval is confirmed before ShelfStack completion;  
* terminal references may be stored;  
* failed internal completion after external approval requires an operational recovery workflow;  
* the system must make such exceptions visible for reconciliation.

Integrated payment processing may later improve end-to-end atomicity.

## Consequences

### Benefits

* Prevents partially posted internal transactions.  
* Prevents duplicate completion.  
* Protects receipt numbering.  
* Keeps inventory, stored value, tender, and POS synchronized.  
* Makes retry behavior safe.

### Costs

* Completion service is technically complex.  
* Locks must be carefully ordered to reduce deadlocks.  
* External card processing remains outside internal atomicity.  
* Recovery and reconciliation tools are still required.

## Alternatives considered

### Post each domain effect independently

Rejected because partial failure would create inconsistent financial and inventory records.

### Assign receipt number when transaction opens

Rejected because cancelled, suspended, and failed transactions must not consume receipt numbers.

### Rely on UI controls to prevent duplicate completion

Rejected because network retries and concurrent requests cannot be safely controlled only through the interface.

## Governing rules

* Completion is one database transaction.  
* Receipt numbers are assigned only during successful completion.  
* Completion requests are idempotent.  
* Reservations convert only when completion succeeds.  
* Stored-value and inventory effects cannot remain without the related completed POS transaction.

## Related domains

* Point of Sale  
* Receiving and Inventory  
* Stored Value  
* Reporting and Reconciliation