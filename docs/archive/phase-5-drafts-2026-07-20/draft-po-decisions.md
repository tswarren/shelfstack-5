The core PO architecture is already settled: one receiving store, normally one vendor, variant-level lines, derived `on_order`, historical line snapshots, receipt linkage at line level, and accepted receipt quantity as the inventory trigger.

The remaining decisions are mostly about the **commercial lifecycle and mutation rules**.

## Decisions to lock before scaffolding

| Decision                                         | Recommended Phase 5 baseline                                                                                                                                                                                                                              |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1. PO number scope and assignment**            | Store-scoped, continuous human-facing number. Assign when the draft is created so staff can reference it immediately. Cancelled drafts retain their number; numbers are never reused.                                                                     |
| **2. Commercial status set**                     | `draft`, `ordered`, `closed`, `cancelled`. Keep receiving progress derived separately as `not_received`, `partially_received`, `fully_received`. Do not include `submitted` or `received` as commercial statuses in Phase 5.                              |
| **3. Meaning of “ordered”**                      | `ordered` means the store has committed or transmitted the order to the vendor. At this transition, validate the PO, snapshot line data, record placement user/time, and begin counting open quantity in `on_order`.                                      |
| **4. Internal submission or approval**           | No separate `submitted` state in Phase 5. Advanced approval routing remains deferred. Placement permission is sufficient for the baseline.                                                                                                                |
| **5. Mutability after placement**                | Vendor, store, currency, and historical line identity become immutable after placement. Do not freely edit ordered quantities or costs in place.                                                                                                          |
| **6. Ordered-line amendments**                   | Allow explicit quantity cancellation against a placed line through `cancelled_quantity`. Increasing ordered quantity should create a new line or explicit amendment operation rather than silently rewriting the original commitment.                     |
| **7. PO cancellation and allocation protection** | A line or PO cannot be cancelled below active customer allocations unless those allocations are released or reassigned in the same transaction. Cancellation records user, time, and reason.                                                              |
| **8. Closing behavior**                          | `closed` means no further ordinary ordering or receiving activity is expected. All remaining open quantity must first be received or cancelled.                                                                                                           |
| **9. Reopening**                                 | No reopening in Phase 5. A mistakenly closed PO requires an explicit correction or replacement PO. This avoids an underspecified historical mutation workflow.                                                                                            |
| **10. Currency**                                 | One currency per PO, normally inherited from the vendor or store policy and snapshotted at creation. For the first release, require it to match the store’s operating currency; foreign-currency purchasing and exchange-rate accounting remain deferred. |
| **11. Vendor-term precedence**                   | Variant-vendor source → store-specific vendor terms, when implemented → organization vendor defaults → manual PO entry. Final values are snapshotted on PO lines.                                                                                         |
| **12. Duplicate variant lines**                  | Prefer one active line per Product Variant and cost/source combination on a draft PO. Merge compatible additions; keep separate lines when source, cost basis, returnability, customer allocation, or operational reason differs.                         |
| **13. Over-receipt**                             | Permit only through an explicit warning and authorized confirmation. Accepted over-receipt increases inventory, but `on_order` cannot become negative. Record the discrepancy.                                                                            |
| **14. Unlinked receiving**                       | Permit receipt lines without a PO-line link only when the user has the appropriate receiving authority and records a reason. This supports unexpected or informal deliveries without inventing a PO after the fact.                                       |

The existing Purchasing domain still explicitly lists status, submission, numbering, vendor-term scope, and reopening as open.  Its proposed status model already points toward `draft`, `ordered`, `closed`, and `cancelled`, with receiving state separated.

## Recommended lifecycle

```text
draft
  ↓ place order
ordered
  ├─ receive partially or fully
  ├─ cancel remaining line quantities
  ├─ cancel entire PO if nothing was received
  ↓ all quantity received or cancelled
closed
```

Receiving remains a derived dimension:

```text
not_received
partially_received
fully_received
```

This prevents the common mistake of using one status field to describe both the commercial order and its physical receipt progress.

## Quantity rules

For each line:

```text
open_quantity
=
ordered_quantity
− accepted_received_quantity
− cancelled_quantity
```

Recommended constraints:

```text
ordered_quantity > 0

0 <= cancelled_quantity <= ordered_quantity

0 <= accepted_received_quantity

open_quantity >= 0
```

For authorized over-receipt, accepted quantity may exceed ordered quantity operationally, but the purchasing projection should use:

```text
on_order_contribution
=
max(
  ordered_quantity
  − accepted_received_quantity
  − cancelled_quantity,
  0
)
```

The current documents define the basic open-quantity formula but have not yet stated how over-receipt is handled.

## Placement contract

The transition from `draft` to `ordered` should atomically:

1. verify the PO is still a draft;
2. verify the store and vendor are active;
3. verify every line has a valid purchasable variant;
4. validate positive quantities;
5. validate packs and order multiples, allowing approved warnings;
6. calculate expected cost;
7. snapshot product, variant, vendor code, cost, and returnability;
8. verify customer allocations do not exceed line supply;
9. assign placement user and timestamp;
10. change status to `ordered`;
11. make open quantity visible in derived `on_order`;
12. write the audit event.

That boundary should be idempotent so retrying placement cannot duplicate expected supply.

## Customer-allocation rule

Only customer requests retain persistent PO allocations. Therefore:

```text
active customer allocations
<= open PO-line quantity
```

Any operation that reduces open quantity must either:

* preserve sufficient quantity for active allocations;
* release selected allocations;
* move them to replacement supply;
* fail atomically.

Staff suggestions, replenishment requests, and frontlist selections normally close when the buyer orders, so they impose no continuing restriction on the PO.

## Decisions that can remain deferred

These should not block the baseline:

* vendor acknowledgements;
* confirmed versus backordered quantities;
* EDI or vendor APIs;
* automatic vendor cascading;
* formal PO approval workflows;
* tiered discount qualification;
* freight allocation and landed cost;
* foreign-exchange accounting;
* reopening placed or closed POs;
* invoices and accounts-payable matching.

The most consequential baseline choices are therefore the **four-state commercial lifecycle, the placement immutability boundary, explicit quantity cancellation, allocation-safe amendments, store-scoped numbering, and no reopening**.
