# Phase 6 — Post-Void Eligibility and Cross-Domain Reversal

**Status:** accepted  
**Needed by:** Phase 6a / 6e  
**Governing area:** Point of Sale / Receiving and Inventory / Product Requests / Stored Value  
**Related:** [ADR-0008](../../adr/0008-immutable-pos-transactions.md); [ADR-0009](../../adr/0009-atomic-idempotent-pos-completion.md); [ADR-0011](../../adr/0011-permissions-authority-and-approvals.md); [point-of-sale](../../domains/point-of-sale.md); [product-requests](../../domains/product-requests.md); [OD-007](od-007-allocation-receipt-and-fulfilment.md); [inventory correction / OD-014](phase-06-inventory-correction-and-od-014.md); [stored-value v1 policy](phase-06-stored-value-v1-operating-policy.md); [Phase 6](../phases/phase-06-corrections-and-stored-value.md)

### Decision

A post-void is a full administrative reversal of exactly one completed POS transaction. It creates a new completed reversing transaction. It never edits, deletes, or reclassifies the original transaction, lines, tenders, inventory postings, stored-value entries, or Product Request fulfilment facts.

Partial correction remains a customer return or another explicit correction workflow—not a partial post-void.

### Schema relationships

| Record | Correction link | Notes |
| --- | --- | --- |
| `pos_transactions` | `reverses_pos_transaction_id` (unique when present) | One completed post-void per original |
| `pos_transactions` | `post_void_reason`, `post_void_pos_approval_id` | Required for completion |
| `pos_transactions` | post-void idempotency key | Existing completion key or dedicated unique correction key |
| `pos_line_items` | `reverses_pos_line_item_id` | Distinct from `original_pos_line_item_id` (customer return) |
| `pos_tenders` | `reverses_pos_tender_id` | Exact one-to-one post-void tender reverse |
| `pos_tenders` | `original_pos_tender_id` | Ordinary / customer-return refund linkage (Phase 6a/6d) |

### Eligibility (all must hold)

Before any reversing record is created:

1. Original transaction is `completed` and belongs to the same store.
2. Original is not itself a post-void.
3. Original has not already been post-voided.
4. Requester has `pos.post_void.create`; an approver with `pos.post_void.approve` records approval (always required in v1; no monetary threshold). Self-approval is permitted only when the requester also holds `pos.post_void.approve_self`; otherwise the approver must be a different user.
5. Every original completed line remains fully reversible (see inventory, units, fulfilment, stored value).
6. No original sale quantity has been customer-returned (any linked return quantity on any sale line blocks full post-void).
7. No original tender has been partially or fully refunded via ordinary refund tenders.
8. Exact inventory units remain in the reversible state expected for each original line.
9. Stored-value entries remain reversible under [stored-value v1 policy](phase-06-stored-value-v1-operating-policy.md).
10. Required standalone card refund or reversal activity has been confirmed externally when the original used card tender.
11. Deficit / settlement state permits reversal under [inventory correction / OD-014](phase-06-inventory-correction-and-od-014.md).
12. For mixed sale-and-return originals: every sale-side and return-side effect is reversible (all-or-nothing).

Failure of any check blocks the post-void; no partial reversing transaction is persisted.

### Construction contract

A dedicated correction operation (not an ordinary editable transaction) must:

1. Lock the current session and original transaction.
2. Evaluate eligibility.
3. Lock original lines and tenders; affected inventory rows and exact units; affected stored-value accounts in stable identifier order; Product Requests when fulfilment reverse applies.
4. Create a new non-editable reversing transaction in the current business day and session.
5. Copy and reverse every original line snapshot (price, discount allocation, tax components, cost, classification).
6. Never consult current catalog, pricing, tax, merchandise classification, return policy, or cost services to recalculate.
7. Reverse inventory effects per [inventory correction / OD-014](phase-06-inventory-correction-and-od-014.md).
8. Reverse stored-value effects per [stored-value v1 policy](phase-06-stored-value-v1-operating-policy.md).
9. Create reversing tenders (`reverses_pos_tender_id`).
10. Reverse Product Request fulfilment where applicable (below).
11. Assign the next store receipt number only on successful commit.
12. Mark reversing lines, tenders, and transaction completed; record approval and reason; commit atomically.

The original transaction remains reported in its original completion period. The post-void reports in the current completion period and references the original.

### Product Request fulfilment

Phase 5 posts fulfilment atomically with sale completion and reverses fulfilment on linked returns via `Requests::ReverseFulfillment`.

Post-void of a fulfilled sale **must reuse that service**. Do not invent a second reversal mechanism.

Rules:

- Leave the original `kind: fulfill` fact intact.
- Append one `kind: reverse` fact per applicable original sale-line fulfilment, linked through `linked_fulfillment_id`.
- Use the post-void reversing line as the correction line identity for posting-key / idempotency (same pattern as a linked-return line).
- Reopen the Product Request when net fulfilled quantity falls below requested quantity (existing derived behavior).
- Eligibility fails when remaining fulfilment quantity cannot be fully reversed for every fulfilled original sale line (for example, prior linked returns already reversed part of the fulfilment—already blocked by the “any return quantity blocks post-void” rule).
- Idempotent retry and full rollback on failure are required.

### Generalized refund tenders (non-post-void)

Phase 4e cash refunds do not link to original tenders. Phase 6a/6d add:

- `original_pos_tender_id` on refund tenders;
- remaining-refundable calculations per original tender;
- for linked returns with mixed original tenders: restore original stored-value tenders first, then eligible external tenders; approval for non-original-tender exceptions;
- prior refunds reduce remaining refundable amounts;
- an original tender may receive multiple ordinary refund tenders up to remaining refundable value;
- post-void tender reversal remains one-to-one via `reverses_pos_tender_id` and is blocked when any ordinary refund already exists against the original.

### Mixed sale-and-return transactions

Mixed completed transactions are valid POS activity and are **in scope** for Phase 6e hardening. Do not quietly defer them.

Policy:

- Support post-void when every sale and return effect on the transaction remains reversible.
- Otherwise mark the entire transaction ineligible (all-or-nothing).

Return-side disposition inverses:

| Original disposition | Inverse on post-void |
| --- | --- |
| `return_to_stock` | Restore quantity/unit to the sold state implied by the original sale being reversed through the mixed transaction’s return line |
| `inspection_required` / `damaged` / `return_to_vendor` | Reverse both on-hand and unavailable ledger effects |
| `discard` | Reverse all inventory ledger entries created by that disposition, in reverse posting order |
| fulfilment reverse created by the return | Append a compensating fulfilment fact as needed so net fulfilment matches post-void commercial reality (append-only; never edit prior facts) |

Exact unit locks and state checks apply to every unit touched by sale or return lines on the original.

### Individually tracked units

Under lock, the exact unit’s current state must still match the reversible expectation:

- reversing an original sale requires the unit still sold by that original line;
- reversing a return requires the unit still in the state created by that return;
- subsequent reserve, resale, discard, transfer, or other change blocks post-void.

Original completed lines remain the historical unit record.

### Permissions and audit

Canonical keys:

```text
pos.post_void.create
pos.post_void.approve
```

Audit retains requester, approver, store, reason, original and reversing records, affected stored-value accounts and balances, external card references, Product Request fulfilment reverses, and blocked-eligibility reason.

### Test categories

- Quantity, individual, non-inventory, open-ring; discounts; multi-tax; cash / card / split tender.
- Stored-value issuance lines and redemption tenders (after 6c/6d).
- Mixed sale-and-return; inspection / damaged / RTV / discard dispositions.
- Product Request fulfilment reverse and reopen; idempotent retry; failed rollback.
- Prior return, prior tender refund, downstream unit activity, consumed stored value, and OD-014 settlement blockers.
- Original unchanged; current configuration changes do not affect reversal; new receipt number; current business day reporting.

### Governing rules

- Completed activity is immutable; corrections create new linked records.
- One post-void per original completed transaction.
- Historical snapshots are copied and reversed; current configuration is not consulted.
- Fulfilment reverse uses `Requests::ReverseFulfillment` only.
- Mixed transactions are all-or-nothing.
- Independent approval is always required for v1 post-void.
