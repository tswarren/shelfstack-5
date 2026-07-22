# Phase 6 — Corrections and Stored Value

> **Non-governing draft.** Promoted guidance lives in [phase-06-corrections-and-stored-value.md](../implementation/phases/phase-06-corrections-and-stored-value.md) and the accepted decision notes: [post-void eligibility](../implementation/decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md), [inventory correction / OD-014](../implementation/decisions/phase-06-inventory-correction-and-od-014.md), [stored-value v1 policy](../implementation/decisions/phase-06-stored-value-v1-operating-policy.md). Prefer those documents over this draft when they disagree.

**Status:** Superseded draft (retained for working notes)
**Depends on:** Phase 4c, Phase 4d, Phase 4e
**Chronologically follows:** Phase 5, although purchasing and receiving are not direct architectural dependencies
**Unlocks:** correction, tender-refund, stored-value liability, and exception reporting in Phase 7
**Governing docs:** ADR-0002, ADR-0008, ADR-0009, ADR-0011, ADR-0012; [stored-value](../../domains/stored-value.md); [point-of-sale](../../domains/point-of-sale.md)

## Goal

Provide explicit, auditable correction of completed POS activity and introduce operational gift card, store credit, and trade credit balances through independent stored-value accounts and an append-only ledger.

Completed activity remains immutable. Corrections create new linked transactions, lines, tenders, inventory postings, and stored-value entries.

## Scope summary

Phase 6 contains two related workstreams:

1. **Corrections**

   * full post-void;
   * generalized refund tenders;
   * exact inventory reversal;
   * stored-value reversal;
   * post-void eligibility and approval.

2. **Stored value**

   * accounts and canonical `21` identifiers;
   * immutable balance ledger;
   * gift-card issuance and reload;
   * redemption as tender;
   * refund to store credit or an existing account;
   * manual adjustment and reversal.

These should remain one roadmap phase because post-void must be tested against stored-value lines and tenders. They should be delivered through separate internal gates.

---

## Governing principles

### Completed records remain immutable

A completed POS transaction, line, tender, inventory posting, or stored-value entry is never edited, deleted, or reclassified to represent a correction.

A correction creates a new record linked to the original.

### Post-void is a full administrative reversal

A post-void:

* creates a new completed POS transaction;
* receives its own receipt number;
* reports in the business day and session in which the reversal completes;
* references exactly one original completed transaction;
* creates one reversing line for each original completed line;
* creates reversing tenders;
* reverses inventory and stored-value effects;
* copies and negates the original historical snapshots;
* never recalculates current price, discount, tax, classification, return policy, or cost.

Partial correction remains a customer return or another later explicit correction workflow.

### Stored value is an independent liability

Stored value is not merchandise inventory and is not ordinary sales revenue.

* Issuance and reload add liability.
* Redemption is tender.
* Refund to stored value increases liability.
* Reversal negates an earlier ledger entry.
* Gift card, store credit, and trade credit remain separately reportable.

### Atomicity and idempotency continue to govern

All internal effects of POS completion commit together or none commit.

Stored-value participation must not weaken the existing completion contract. Repeating the same completion or post-void request must not create duplicate:

* receipts;
* reversing transactions;
* tenders;
* inventory postings;
* stored-value entries;
* account balance changes.

---

# Delivery gates

## Phase 6a — Correction and reversal foundation

### Schema extensions

Add correction relationships to existing POS records:

#### `pos_transactions`

* `reverses_pos_transaction_id`
* `post_void_reason`
* `post_void_pos_approval_id`
* post-void idempotency support, either through the existing completion key or a separate unique correction key

`reverses_pos_transaction_id` must be unique when present so one original transaction cannot receive two completed post-voids.

#### `pos_line_items`

* `reverses_pos_line_item_id`

A post-void reversing line references exactly one original completed line. This remains distinct from `original_pos_line_item_id`, which represents a customer return relationship.

#### `pos_tenders`

* `original_pos_tender_id`, for partial or customer-return refunds;
* `reverses_pos_tender_id`, for an exact post-void reversal;
* `stored_value_account_id`, introduced with stored-value tender support.

An original tender may receive multiple ordinary refund tenders up to its remaining refundable value. A post-void reversal is one-to-one.

### Inventory reversal contract

Quantity-tracked corrections must reverse the exact inventory ledger entries created by the original transaction.

Use the existing:

* `posting_key`;
* `reversal_of_entry_id`;
* original quantity delta;
* original inventory-value delta;
* original cost values.

Do not calculate a new moving-average cost for the historical reversal.

Before post-void implementation, ensure that changes to `unavailable` are also explicitly reversible. The preferred implementation is to add an `unavailable_delta` and resulting unavailable snapshot to inventory ledger posting. Inspection, damaged, and RTV return effects must not depend on an unexplained direct balance mutation.

Discard dispositions may have produced more than one inventory entry. Post-void reverses all entries associated with the original line in reverse posting order.

### Individually tracked units

A reversing operation must validate the exact unit’s current state under lock.

Examples:

* reversing an original sale requires the unit still to be sold by that original line;
* reversing a return requires the unit still to be in the state created by that return;
* a subsequently reserved, resold, discarded, transferred, or otherwise changed unit blocks post-void.

The original sale and return lines remain the historical unit record. Current unit status may change through the correction, but the original completed lines are not changed.

### Post-void eligibility evaluator

Before any reversal is created, validate that:

* the original transaction is completed;
* the original transaction belongs to the same store;
* it is not itself a post-void transaction;
* it has not already been post-voided;
* all original completed lines remain fully reversible;
* no original sale quantity has been returned;
* no original tender has been partially or fully refunded;
* exact inventory units remain in their expected reversible states;
* stored-value entries remain reversible;
* required standalone card refund or reversal activity has been confirmed externally;
* the requester has `pos.post_void`;
* the required independent approval has been recorded.

Post-void should require independent approval for the initial implementation rather than relying on an unresolved monetary threshold.

### Gate exit

A completed quantity-tracked or individually tracked transaction paid by cash or standalone card can be fully post-voided without modifying the original transaction.

---

## Phase 6b — Stored-value account and ledger foundation

### Account policy decisions

Use the following initial account types:

```text
gift_card
store_credit
trade_credit
```

Account type is immutable.

Use the following initial statuses:

```text
active
suspended
```

A zero balance is derived and does not create a `depleted` status.

Replacement, closure, transfer, expiration, and multiple credentials remain deferred.

A suspended account blocks ordinary issuance, reload, and redemption. Authorized refunds and corrective reversals may still post when required to preserve historical accuracy.

### `stored_value_accounts`

Required fields:

* `organization_id`
* `account_type`
* `account_number`
* `alternate_identifier`
* `status`
* `current_balance_cents`
* `lock_version`
* `created_by_user_id`
* timestamps

Rules:

* `account_number` is a generated canonical `21` EAN-13 identifier;
* the canonical number is organization-wide unique, immutable, never reused, and scannable;
* `alternate_identifier`, when present, is organization-wide unique for deterministic stored-value lookup;
* `current_balance_cents` is a required operational cache with default zero;
* the ledger remains authoritative;
* balance may not become negative;
* a zero-balance active account remains valid and may later be issued or reloaded.

An account may be created before its first issuance. Creation of a zero-balance account does not create liability.

### `stored_value_entries`

Required fields:

* `stored_value_account_id`
* `store_id`
* `entry_type`
* signed `amount_cents`
* `pos_transaction_id`
* `pos_line_item_id`
* `pos_tender_id`
* `reverses_entry_id`
* `stored_value_adjustment_reason_id`
* `description`
* `created_by_user_id`
* `pos_approval_id`
* unique `posting_key`
* `created_at`

Ledger entries should not have an ordinary editing lifecycle.

Recommended entry types:

```text
issued
reloaded
redeemed
refunded
adjusted
reversed
```

Rules:

* positive amounts add value;
* negative amounts consume value;
* issuance, reload, and refund entries are positive;
* redemption entries are negative;
* adjustment entries may be positive or negative;
* a reversal is the exact opposite amount of the entry it references;
* one entry may be reversed at most once;
* amount must be non-zero;
* POS-originated entries identify the applicable line or tender;
* manual adjustments identify a reason, actor, approval, and description;
* entries cannot be updated or deleted.

A generic `reversed` type is preferred over separate `issuance_reversed`, `redemption_reversed`, and similar types. Reporting can classify the reversal from the referenced original entry.

### Balance posting contract

One stored-value posting operation owns account balance changes.

It must:

1. lock the account;
2. check status and operation eligibility;
3. check the unique posting key;
4. validate sufficient balance for a debit;
5. create the immutable entry;
6. update the cached balance;
7. record audit information;
8. commit atomically.

When one POS transaction affects several stored-value accounts, lock accounts in stable identifier order to reduce deadlocks.

### Manual adjustments

`stored_value_adjustment_reasons` is required because manual adjustment is in scope.

Suggested fields:

* `organization_id`
* `code`
* `name`
* `description`
* `requires_note`
* `active`
* `position`
* timestamps

For the initial implementation, every manual adjustment requires:

* `stored_value.adjust`;
* an active reason;
* explanatory text when required by the reason;
* an independent approval;
* an immutable ledger entry.

### Gate exit

Stored-value accounts can be created and found by canonical or alternate identifier. Authorized credits and debits update the ledger and cached balance atomically. Concurrent debits cannot overspend an account.

---

## Phase 6c — Gift-card issuance and reload

### Stored-value POS lines

Extend POS line kinds to include:

```text
stored_value
```

A stored-value line records:

* the stored-value account;
* operation: `issue` or `reload`;
* account-type snapshot;
* description snapshot;
* amount;
* no ordinary product variant;
* no inventory unit;
* no inventory reservation;
* no ordinary merchandise tax;
* no ordinary revenue department posting.

The current POS schema must allow stored-value lines without an ordinary merchandise department. Reporting excludes these lines from gross merchandise sales and classifies them as stored-value liability activity.

### Issuance

Gift-card issuance:

1. resolves or creates a zero-balance gift-card account;
2. adds a stored-value issuance line;
3. is funded by ordinary received tender;
4. creates a positive `issued` ledger entry at completion;
5. updates the cached balance;
6. completes atomically with the POS transaction.

A cancelled or failed POS transaction creates no issuance ledger entry and no liability.

### Reload

Reload:

* applies to an existing active gift-card account;
* is funded by ordinary tender;
* creates a positive `reloaded` entry;
* commits with the related POS transaction.

Initial policy:

* gift cards may be reloaded;
* store credit may not be cash-funded or manually reloaded through POS;
* trade credit may not be issued or reloaded through POS in this phase.

Stored-value lines are not ordinary customer-returnable merchandise. Their correction path is post-void or an authorized stored-value adjustment.

### Gate exit

Gift-card issuance and reload work end to end and remain safe under completion retry and transaction rollback.

---

## Phase 6d — Redemption and refund to stored value

### Redemption tender

A stored-value redemption is a received POS tender.

The tender:

* references one stored-value account;
* validates available balance under account lock;
* creates a negative `redeemed` ledger entry;
* reduces the cached balance;
* participates in split tender;
* is not a discount;
* does not reduce taxable merchandise amount;
* commits atomically with POS completion.

Several stored-value tenders may be used when allowed by policy, but the same account must not be added redundantly in a way that bypasses balance validation.

### Refund to stored value

A stored-value refund is a refunded POS tender.

It:

* references the destination account;
* creates a positive `refunded` ledger entry;
* increases the account balance;
* remains linked to the return transaction and applicable original tender or return basis.

Store-credit refunds may create a new zero-balance `store_credit` account before completion and credit it only when the return transaction completes.

### Original-tender restoration

For linked returns:

1. determine remaining refundable value on each original tender;
2. restore original stored-value tenders first;
3. refund the remaining amount to eligible external tenders;
4. require approval for any non-original-tender exception.

Prior refunds must reduce the remaining refundable amount.

### Trade-credit boundary

Phase 6 creates the trade-credit account type and allows reporting and policy configuration.

Actual trade-credit issuance from customer buyback remains deferred. Redemption of migrated or authorized manually established trade-credit balances may be supported under the same balance rules.

### Standalone card refunds

Card refunds remain externally processed.

ShelfStack requires confirmation and may record:

* authorization or reference code;
* terminal reference;
* refund timestamp;
* responsible user.

A failed or unconfirmed external refund blocks internal completion. ShelfStack does not silently substitute a reconciliation adjustment.

### Gate exit

Stored value can participate safely in split tender, linked-return restoration, no-receipt store-credit refunds, and completion retry.

---

## Phase 6e — Integrated post-void and hardening

### Post-void construction

Post-void should not be assembled as an ordinary editable transaction.

A dedicated correction operation should:

1. lock the current session;
2. lock the original transaction;
3. evaluate post-void eligibility;
4. lock original lines and tenders;
5. lock affected inventory rows and exact units;
6. lock affected stored-value accounts in stable order;
7. create a new non-editable reversing transaction;
8. copy and reverse every original line snapshot;
9. copy and reverse every original tax component and discount allocation;
10. reverse inventory effects;
11. reverse stored-value effects;
12. create reversing tenders;
13. assign the next store receipt number;
14. mark the reversing lines, tenders, and transaction completed;
15. record the approval and reason;
16. commit.

Current catalog, pricing, tax, merchandise classification, return policy, and cost services must not be used to recalculate the historical reversal.

### Stored-value post-void rules

Negative entries such as redemption can ordinarily be reversed by adding the exact amount back.

Positive entries such as issuance, reload, or refund can be reversed only when the required value remains available.

For the initial implementation, use a conservative rule:

> Any later redemption from the account blocks reversal of an earlier positive POS-originated credit.

This avoids inventing balance-lot attribution. A more permissive allocation model may be designed later.

### Reporting-period behavior

The original transaction remains reported in its original completion period.

The post-void reports in the current completion period and references the original transaction.

Original session, business-day, receipt, tender, tax, and inventory records remain unchanged.

---

## Permissions and approvals

Required permissions should include:

```text
pos.post_void
pos.approve_post_void

stored_value.view_balance
stored_value.view_ledger
stored_value.create_account
stored_value.issue
stored_value.reload
stored_value.redeem
stored_value.refund
stored_value.adjust
stored_value.suspend
```

Replacement and transfer permissions remain deferred.

Audit must retain:

* requester;
* approver;
* store;
* reason;
* original and reversing records;
* affected stored-value account;
* original and resulting balance;
* external card references where applicable;
* blocked post-void reason.

---

## Required test matrix

### Post-void

* quantity-tracked sale;
* individually tracked sale;
* non-inventory service;
* open-ring line;
* discounts and allocated transaction discounts;
* multiple tax components;
* cash tender;
* standalone card tender;
* split tender;
* stored-value issuance line;
* stored-value redemption tender;
* mixed sale and return transaction;
* inspection, damaged, RTV, and discard dispositions;
* original transaction remains unchanged;
* current configuration changes do not affect reversal;
* duplicate post-void submission is idempotent;
* second post-void is blocked;
* partial return blocks full post-void;
* prior tender refund blocks full post-void;
* subsequent exact-unit activity blocks full post-void;
* failed reversal rolls back every internal effect;
* reversal receives a new receipt number;
* reversal reports under the current business day.

### Stored value

* canonical `21` identifier generation;
* alternate-identifier uniqueness;
* issuance;
* reload;
* redemption;
* refund to existing account;
* new store-credit account refund;
* split tender;
* insufficient balance;
* suspended account behavior;
* concurrent redemptions with only one successful overspend contender;
* completion retry creates no duplicate entry;
* rollback leaves ledger and cached balance unchanged;
* manual positive adjustment;
* manual negative adjustment;
* approval and reason requirements;
* immutable ledger enforcement;
* one reversal per entry;
* cached balance reconciles to ledger sum.

---

## Exit criteria

* [ ] Completed transactions, lines, tenders, inventory entries, and stored-value entries remain immutable.
* [ ] A post-void creates one new completed transaction linked to one original completed transaction.
* [ ] Post-void uses exact historical line, discount, tax, cost, inventory, tender, and stored-value facts.
* [ ] Current product, price, tax, classification, and policy configuration is not consulted to recalculate a post-void.
* [ ] Quantity and individually tracked inventory effects reverse exactly.
* [ ] Prior returns, refunds, downstream unit activity, or consumed stored value block post-void where full reversal is impossible.
* [ ] Gift-card issuance and reload commit atomically with ordinary tender.
* [ ] Stored-value redemption and refunds commit atomically with POS tenders.
* [ ] The stored-value ledger is authoritative and append-only.
* [ ] The cached account balance updates atomically and reconciles to the ledger.
* [ ] Concurrent redemption cannot overspend an account.
* [ ] Completion and post-void remain idempotent when stored value participates.
* [ ] Store credit may be issued through an eligible refund.
* [ ] Trade-credit infrastructure exists without implementing buyback issuance.
* [ ] All restricted activity retains requester, approver, reason, store, and source relationships.

---

## Out of scope

* partial post-void;
* editing or deleting completed activity;
* reconciliation adjustments, except for Phase 7 interfaces;
* stored-value replacement;
* multiple physical or digital credentials per account;
* account transfer or consolidation;
* expiration;
* escheatment;
* jurisdiction-specific stored-value law;
* customer-facing balance portals;
* gift-card cash-out;
* buyback and ordinary trade-credit issuance;
* integrated payment processing;
* processor settlement and chargeback workflows;
* offline stored-value authorization.

---

## Related

* [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
* [phase-05-supply-and-demand.md](phase-05-supply-and-demand.md)
* [../deferred-capabilities.md](../deferred-capabilities.md)
* [../../domains/stored-value.md](../../domains/stored-value.md)
* [../../domains/point-of-sale.md](../../domains/point-of-sale.md)
