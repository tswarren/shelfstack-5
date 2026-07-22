# Phase 6 — Corrections and Stored Value

**Status:** Implementation complete for gates 6a–6e; [#36](https://github.com/tswarren/shelfstack-5/issues/36) merge / first-install hardening in progress. Interim exit criteria below remain intentionally open after #36.  
**Depends on:** Phase 4c, Phase 4d, Phase 4e; Phase 5 fulfilment integration (post-void must reverse Product Request fulfilment facts)  
**Chronologically follows:** Phase 5 — purchasing and receiving are not conceptual prerequisites for stored value  
**Unlocks:** correction, tender-refund, stored-value liability, and exception reporting in Phase 7  
**Governing docs:** ADR-0002, ADR-0008, ADR-0009, ADR-0011, ADR-0012; [stored-value](../../domains/stored-value.md); [point-of-sale](../../domains/point-of-sale.md); [post-void eligibility](../decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md); [inventory correction / OD-014](../decisions/phase-06-inventory-correction-and-od-014.md); [stored-value v1 policy](../decisions/phase-06-stored-value-v1-operating-policy.md)

### Pre-production data note (unavailable ledger)

After applying the `unavailable_delta` / `resulting_unavailable` migration, **reset or re-seed** pre-production operational inventory and POS transactional data. Zero-backfilled historical ledger rows are not authoritative unavailable history; do not invent a production backfill in this phase.

## Goal

Correct completed POS activity with linked reversing records, and govern gift card / store credit / trade credit through independent accounts and an append-only ledger.

Completed activity remains immutable. Corrections create new linked transactions, lines, tenders, inventory postings, stored-value entries, and Product Request fulfilment reverses.

## Scope summary

Two related workstreams, one roadmap phase (post-void must be tested against stored-value lines and tenders), delivered through internal gates:

1. **Corrections** — full post-void; generalized refund tenders; exact inventory reversal; stored-value reversal; eligibility and approval; Product Request fulfilment reverse via `Requests::ReverseFulfillment`.
2. **Stored value** — accounts and `21` identifiers; append-only ledger; gift-card issue/reload; redemption as tender; refund to store credit; manual adjustment.

Detail lives in the three Phase 6 decision notes linked above—not in this phase file.

## Governing principles

- Completed records are never edited, deleted, or reclassified to represent a correction.
- Post-void is a full administrative reversal: new completed transaction, own receipt number, current business day/session, exact historical snapshots, no current-config recalculation.
- Stored value is independent liability: issuance/reload add liability; redemption is tender; types remain separately reportable.
- Atomicity and idempotency continue to govern when stored value and corrections participate.

## Delivery gates

| Gate | Focus | Decision anchors |
| --- | --- | --- |
| **6a** | Correction foundation: schema links, refund-tender linkage, inventory unavailable ledger fields, ordinary post-void (cash/card), fulfilment reverse, OD-014 interim block | post-void eligibility; inventory / OD-014 |
| **6b** | Stored-value accounts, ledger, posting contract, manual adjustments | stored-value v1 policy |
| **6c** | Gift-card issuance and reload POS lines (`stored_value` line kind; nullable department) | stored-value v1 policy |
| **6d** | Redemption tender; refund to stored value; original-tender restoration | stored-value v1 policy; post-void eligibility (refund linkage) |
| **6e** | Integrated post-void with stored value; mixed sale+return hardening; remove or replace OD-014 interim block only after algorithm lands | all three decisions |

### Principal tables / extensions

**POS correction links:** `pos_transactions.reverses_pos_transaction_id` (unique when present), post-void reason/approval/idempotency; `pos_line_items.reverses_pos_line_item_id`; `pos_tenders.reverses_pos_tender_id`, `original_pos_tender_id`, `stored_value_account_id`.

**Card refund preparations:** `pos_card_refund_preparations` (UUID) — durable terminal-bound plan with snapshot/fingerprint; statuses `prepared` / `recorded_tender` / `recorded_orphan` / `abandoned`. While `prepared`, commercial edit/complete/cancel/suspend are blocked regardless of TTL. Orphans are external-payment facts, not tenders on closed history.

**Inventory:** ledger `unavailable_delta`, `resulting_unavailable` (optional disposition snapshot); migrate return/receipt unavailable mutations onto ledger-owned posting.

**Stored value:** `stored_value_accounts`, `stored_value_entries`, `stored_value_adjustment_reasons`. Alternate identifiers are immutable after create; normalized (strip/hyphen/case) uniqueness is organization-scoped and shares occupation space with canonical account numbers.

**POS lines:** `line_kind` includes `stored_value`; `department_id` nullable for those lines; account + operation snapshots; no merchandise tax/inventory/revenue.

### Principal services (expected)

- Post-void eligibility evaluator and dedicated post-void construction operation
- Inventory ledger posting extended for unavailable + reversing entries
- Reuse `Requests::ReverseFulfillment` from post-void (no second mechanism)
- Stored-value account resolve/create; balance posting; issue/reload/redeem/refund/adjust
- Generalized refund tender with remaining-refundable and restoration order

Permissions: [authorization-permissions.md](../../domains/authorization-permissions.md) (`pos.post_void.create` / `pos.post_void.approve`; `stored_value.*` rows).

## Implementation order

1. Accept decision notes (done) and sync domain / permission catalog / locks.
2. 6a schema + unavailable ledger path + ordinary post-void + fulfilment reverse + refund linkage stubs.
3. 6b account/ledger foundation with concurrency tests.
4. 6c gift-card issue/reload end to end.
5. 6d redemption, refund to SV, restoration order.
6. 6e integrated post-void, mixed-txn matrix, OD-014 algorithm or retained interim block.

## Exit criteria

Proven by tests in this branch unless noted:

- [x] Completed transactions, lines, tenders, inventory entries, stored-value entries, and fulfilment facts remain immutable
- [x] Post-void creates one new completed transaction linked to one original; uses exact historical facts; current config is not consulted (incl. cloned `PosDiscount` rows)
- [x] Quantity-tracked inventory reverse (incl. OD-014 Case-1 exact deficit pool) and individually tracked unit restore when eligible; unavailable reverses through the ledger
- [x] Prior returns, refunds (including pending/authorized in-flight), post-void consumption of returnable/refundable, downstream unit activity, consumed stored value, or OD-014 later deficit quantity change / reverse-into-deficit block post-void / later return-refund where full reversal is impossible
- [x] Post-void of a fulfilled sale reverses fulfilment via `Requests::ReverseFulfillment` and reopens the request when derived quantity requires it (happy-path covered; broader matrix remains in decision notes)
- [x] Gift-card issue/reload and SV redeem/refund commit atomically with POS; ledger append-only; cache reconciles; concurrent redeem cannot overspend; original-tender-first refund + exception approval
- [x] Completion and post-void remain idempotent when stored value participates; AdjustBalance posting_key idempotent
- [x] Store credit may issue through eligible refund when no original SV remains (or with exception approval); trade-credit infrastructure exists without buyback issuance
- [ ] Mixed sale+return post-void supported only when every effect is reversible (all-or-nothing) — **retained block** until fulfilment restoration lands
- [x] Restricted activity retains requester, approver, reason, store, and source relationships

**Retained interim blocks:** OD-014 post-settlement algorithm (any later deficit-quantity change after a deficit-affecting original that increased *or reduced* deficit, or reverse that would settle current deficit when the original did not change deficit); return-containing / mixed-txn post-void (needs fulfilment restoration).

## Test categories

Post-void (including mixed txn, dispositions, fulfilment, OD-014 blockers, in-flight refund blockers, idempotency, rollback); stored value (identifiers, issue/reload/redeem/refund, split tender, concurrency, manual adjustment, immutable ledger). Suspend/unsuspend operational workflow is deferred (permission seeded; no service/UI in Gate 6d). Full matrices in the decision notes.

## Out of scope

- Partial post-void; editing/deleting completed activity
- Reconciliation adjustments (Phase 7 interfaces only)
- Stored-value replacement, multi-credential, transfer, expiration, escheatment, cash-out, customer portals
- Buyback and ordinary trade-credit issuance
- Integrated payment processing; offline stored-value authorization
- Closing OD-010 status-bucket unavailable model
- Permanent OD-014 post-settlement block (interim only until algorithm ships)

## Related

- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
- [phase-05-supply-and-demand.md](phase-05-supply-and-demand.md)
- [../deferred-capabilities.md](../deferred-capabilities.md)
- [../../domains/stored-value.md](../../domains/stored-value.md)
- [../../domains/point-of-sale.md](../../domains/point-of-sale.md)
