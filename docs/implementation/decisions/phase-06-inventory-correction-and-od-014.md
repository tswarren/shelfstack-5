# Phase 6 — Inventory Correction and OD-014 Interaction

**Status:** accepted  
**Needed by:** Phase 6a  
**Governing area:** Receiving and Inventory / Point of Sale / Reporting  
**Related:** [ADR-0008](../../adr/0008-immutable-pos-transactions.md); [ADR-0013](../../adr/0013-govern-quantity-tracked-inventory-cost.md); [OD-014 settlement](od-014-negative-inventory-settlement.md); [OD-010](../open-decisions.md) (remains open); [post-void eligibility](phase-06-post-void-eligibility-and-cross-domain-reversal.md); [Phase 6](../phases/phase-06-corrections-and-stored-value.md)

### Decision

Phase 6 inventory corrections (post-void and disposition-bearing return reverse) must reverse through the inventory ledger. Aggregate `unavailable` changes must be ledger-owned. Post-void interaction with the OD-014 aggregate deficit-cost pool is a state-transition problem: blindly negating an original sale ledger row is not always sufficient after later settlement.

### Aggregate unavailable on the ledger

Today, customer-return and receipt posting can change `stock_balances.unavailable` outside the ledger. That prevents full reproduction of unavailable history and blocks safe post-void of disposition-bearing returns.

**Accepted Phase 6a precondition** — extend inventory ledger posting with (or equivalent):

| Field | Role |
| --- | --- |
| `unavailable_delta` | Signed change to aggregate unavailable applied by this entry |
| `resulting_unavailable` | Snapshot of aggregate unavailable after the entry |
| optional disposition / availability reason snapshot | Explains why unavailable changed (for example return disposition) |

Rules:

- Only ledger-owned posting mutates `stock_balances.unavailable` for quantity-tracked balances.
- `Inventory::PostCustomerReturn` and `Inventory::PostReceipt` (accepted unavailable) use the same path.
- Discard and multi-entry dispositions reverse all associated ledger entries in reverse posting order.
- Do **not** introduce status-specific unavailable buckets in Phase 6. [OD-010](../open-decisions.md) (aggregate total vs status balances) remains open.

### Ordinary inventory reverse (non-deficit or still-open deficit)

For quantity-tracked corrections that do not require post-settlement reconstruction:

1. Locate the original inventory ledger entries for the POS line (`posting_key` / source linkage).
2. Create reversing entries with `reversal_of_entry_id`, opposite quantity and inventory-value deltas, and opposite `unavailable_delta` where applicable.
3. Copy original cost values; do not recalculate moving-average cost for the historical reverse.
4. Update `on_hand`, inventory value, moving average, and open provisional deficit cost through the same posting service used for other movements (OD-014 pool bookkeeping remains generic inside ledger posting).

Individually tracked units reverse under exact-unit locks per [post-void eligibility](phase-06-post-void-eligibility-and-cross-domain-reversal.md).

### OD-014 post-void cases

OD-014 uses an aggregate Store-and-Variant deficit-cost pool with no origin match between receipts and individual negative sales. Later receipts may post `receipt_deficit_settlement` (and variance / late-cost recognition) and then positive `receipt` entries.

At least four cases must be distinguished for a deficit-creating original sale:

| Case | Situation | Phase 6 disposition |
| --- | --- | --- |
| 1 | Original sale’s deficit contribution remains completely open — no later deficit-settlement (or other pool-settling) activity for that store-and-variant after the sale’s outbound entry | Exact reverse of the original sale ledger entry(ies), including provisional deficit pool effects created by that entry |
| 2 | Deficit partially settled by later receipt activity | **Blocked** under interim eligibility (below) until full algorithm ships |
| 3 | Deficit fully settled by later receipt activity | **Blocked** under interim eligibility until full algorithm ships |
| 4 | Later activity moved the balance back into positive inventory | **Blocked** under interim eligibility until full algorithm ships |

Linked customer returns that reduce open deficit without creating receipt variance remain governed by OD-014 (“use original completed cost; do not create ordinary receipt cost variance”). Post-void of an ordinary (non-deficit or still-open-deficit) sale follows the ordinary reverse path above.

### Interim eligibility block (accepted for 6a start)

Until the full post-settlement correction algorithm is accepted and implemented:

> Block post-void of a quantity-tracked original sale line when that line’s outbound inventory entry increased the open deficit pool **and** any later `receipt_deficit_settlement` (or other movement that released open provisional deficit cost or created positive inventory from a prior deficit) has posted for the same store-and-variant after that outbound entry.

This is safer than an incomplete reverse-as-negate. The block is temporary and must be replaced by the algorithm below—not treated as a permanent product rule.

### Target correction algorithm (to implement before removing the block)

When post-void (or an inventory correction) must undo a deficit-creating sale after settlement activity, create new reversing / compensating ledger facts that restore consistency of:

1. On Hand quantity;
2. positive inventory asset value and moving average when On Hand is positive;
3. open provisional deficit cost and deficit cost quality;
4. recorded settlement variance and late-cost recognition previously posted on deficit-settlement entries that are no longer consistent after the correction.

Constraints:

- Original sale snapshots and original settlement entries remain immutable.
- No origin-matching table is introduced; compensation remains at aggregate Store-and-Variant level with explicit auditable ledger facts.
- Do not invent acquisition cost; unknown vs confirmed-zero distinctions from ADR-0013 / OD-014 remain.
- Monetary variance / late-cost reversal facts are separate non-quantity facts associated with the correcting ledger entries, mirroring how settlement recorded them.
- Entire post-void remains atomic with POS, tender, stored-value, and fulfilment reverses.

Detailed formulas for proportional pool restoration and variance reversal must be specified in the implementation PR that removes the interim block and covered by concurrency / reversal tests for cases 2–4.

### Returns that created unavailable

Post-void of a mixed or return-bearing transaction must reverse unavailable through the new ledger fields. Direct balance mutation is not an acceptable reverse path.

### Governing rules

- Inventory corrections create reversing ledger entries; they do not edit posted entries.
- Aggregate unavailable is ledger-owned in Phase 6+.
- OD-010 status buckets remain undecided.
- Post-settlement deficit post-void is blocked until the full algorithm lands.
- Case 1 (still-open deficit) uses exact historical reverse including pool effects.
- Completed POS cost snapshots are never rewritten.
