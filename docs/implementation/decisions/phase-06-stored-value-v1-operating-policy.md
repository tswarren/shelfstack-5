# Phase 6 — Stored-Value v1 Operating Policy

**Status:** accepted  
**Needed by:** Phase 6b–6e  
**Governing area:** Stored Value / Point of Sale / Authorization  
**Related:** [ADR-0002](../../adr/0002-canonical-identifiers-and-namespaces.md); [ADR-0008](../../adr/0008-immutable-pos-transactions.md); [ADR-0009](../../adr/0009-atomic-idempotent-pos-completion.md); [ADR-0012](../../adr/0012-stored-value-ledger.md); [stored-value](../../domains/stored-value.md); [authorization-permissions](../../domains/authorization-permissions.md); [post-void eligibility](phase-06-post-void-eligibility-and-cross-domain-reversal.md); [Phase 6](../phases/phase-06-corrections-and-stored-value.md)

### Decision

Phase 6 delivers operational gift card, store credit, and trade credit through independent accounts and an append-only ledger. The choices below close open Phase 6 operating questions for v1 without adopting deferred capabilities (replacement, transfer, expiration, buyback issuance, multi-credential).

### Account types

```text
gift_card
store_credit
trade_credit
```

Account type is immutable after create. Types remain separately reportable.

### Account statuses (v1)

```text
active
suspended
```

- `depleted` is derived from balance (zero balance does not change status).
- `closed` and `replaced` wait for their workflows (deferred).
- Suspended accounts block ordinary issuance, reload, and redemption.
- Authorized refunds and corrective reversals may still post when required for historical accuracy.

### Identity and balance

- Canonical `account_number` is a generated organization-wide unique, immutable, never-reused `21` EAN-13.
- Optional `alternate_identifier` is organization-wide unique when present.
- `current_balance_cents` is a required operational cache (default zero); the ledger is authoritative.
- Balance may not become negative.
- An account may be created at zero balance before first issuance; creation alone creates no liability.

### Ledger entry taxonomy (v1)

```text
issued
reloaded
redeemed
refunded
manual_adjustment
reversal
```

Rules:

- Positive amounts add value; negative amounts consume value.
- Issuance, reload, and refund entries are positive; redemption entries are negative.
- `manual_adjustment` may be positive or negative and requires reason, actor, and approval.
- `reversal` is the exact opposite amount of the entry referenced by `reverses_entry_id`.
- One entry may be reversed at most once.
- Prefer generic `reversal` over separate `issuance_reversed` / `redemption_reversed` types; reporting classifies from the referenced entry.
- Entries are append-only (no update/delete lifecycle).
- Unique `posting_key` per entry; POS-originated entries identify applicable line or tender.

### Balance posting contract

One stored-value posting operation owns account balance changes: lock account → check status and eligibility → check posting key → validate sufficient balance for debit → create immutable entry → update cached balance → audit → commit. When one POS transaction affects several accounts, lock in stable identifier order.

### POS line schema for stored value

Expand `pos_line_items` for `line_kind = stored_value`:

- No ordinary merchandise `department_id` — **`department_id` is null** for stored-value lines (no fabricated Gift Card Department).
- No product variant, inventory unit, or inventory reservation.
- Require `stored_value_account_id` and operation (`issue` / `reload`), with account-type and description snapshots.
- No ordinary merchandise tax, revenue department posting, discounts, or margin.
- Reporting uses account type and ledger entry type as classification dimensions.
- Check constraints must expand beyond `product` / `open_ring` variant shape rules.

### Reload policy (v1)

| Account type | Cash-funded issue via POS | Cash-funded reload via POS |
| --- | --- | --- |
| `gift_card` | yes | yes |
| `store_credit` | no (issue via eligible refund) | no |
| `trade_credit` | no | no |

Trade-credit infrastructure, lookup, reporting, and redemption of authorized migrated or manually established balances may be supported under the same balance rules. Buyback issuance remains deferred.

### Redemption and refund

- Redemption is a received tender, not a discount; it does not reduce taxable merchandise amount.
- Refund to stored value is a refunded tender creating a positive `refunded` entry.
- Store-credit refunds may create a new zero-balance `store_credit` account and credit it only when the return completes.
- Linked-return restoration order: restore original stored-value tenders first, then eligible external tenders; approval for non-original-tender exceptions ([post-void eligibility](phase-06-post-void-eligibility-and-cross-domain-reversal.md)).

### Manual adjustment approval (v1)

Every manual adjustment requires:

- `stored_value.adjustment.create`;
- an active adjustment reason;
- explanatory text when the reason requires a note;
- independent `stored_value.adjustment.approve`;
- an immutable `manual_adjustment` ledger entry.

This closes the domain open question “what adjustment threshold requires Approval?” for v1 (always).

### Post-void and stored value

- Negative entries (for example redemption) reverse by restoring the exact amount.
- Positive POS-originated credits (issue, reload, refund) reverse only when required value remains available.
- Conservative v1 rule: any later redemption from the account blocks reversal of an earlier positive POS-originated credit (no balance-lot attribution yet).

### Canonical permissions

Normalize to `<domain>.<resource>.<action>` and seed in Phase 6:

| Key | Description | Scope | Approvals | Audit |
| --- | --- | --- | --- | --- |
| `stored_value.account.view` | View account and current balance | store | no | no |
| `stored_value.ledger.view` | View ledger history | store | no | no |
| `stored_value.account.create` | Create zero-balance accounts | store | no | yes |
| `stored_value.account.suspend` | Suspend / unsuspend accounts | store | no | yes |
| `stored_value.issue` | Issue gift-card value through POS | store | no | yes |
| `stored_value.reload` | Reload gift-card value through POS | store | no | yes |
| `stored_value.tender.redeem` | Redeem stored value as tender | store | no | yes |
| `stored_value.tender.refund` | Refund to stored value | store | no | yes |
| `stored_value.adjustment.create` | Create manual adjustments | store | yes | yes |
| `stored_value.adjustment.approve` | Approve manual adjustments | store | — | yes |

Replacement and transfer permissions remain deferred. Post-void keys remain under `pos.*` (`pos.post_void.create`, `pos.post_void.approve`).

### Out of scope (deferred)

Replacement, multiple credentials, transfer/consolidation, expiration, escheatment, jurisdiction-specific law, customer portals, gift-card cash-out, buyback / ordinary trade-credit issuance, integrated payments, offline authorization.

### Governing rules

- Ledger is authoritative and append-only.
- Cached balance reconciles to the ledger and updates atomically.
- Issuance creates liability; redemption is tender.
- Gift card, store credit, and trade credit remain separately reportable.
- No ordinary merchandise department on stored-value POS lines.
- Concurrent redemption cannot overspend an account.
