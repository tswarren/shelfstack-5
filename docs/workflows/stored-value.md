# Workflow: Stored Value — Account, Issue/Reload, Redeem/Refund, Adjust, Reverse

**Status:** Delivered in Phase 6b/6c/6d for v1 operating policy
**Type:** Record-level workflow
**Governing:** [ADR-0002](../adr/0002-canonical-identifiers-and-namespaces.md), [ADR-0008](../adr/0008-immutable-pos-transactions.md), [ADR-0009](../adr/0009-atomic-idempotent-pos-completion.md), [ADR-0011](../adr/0011-permissions-authority-and-approvals.md), [ADR-0012](../adr/0012-stored-value-ledger.md), [phase-06 stored-value policy](../implementation/decisions/phase-06-stored-value-v1-operating-policy.md), [stored-value domain](../domains/stored-value.md), [service-catalog](../implementation/service-catalog.md)

## Purpose

Stored Value manages gift card, store credit, and trade credit accounts through an append-only ledger. POS issuance, reload, redemption, refund, and reversal are coordinated through POS services, while `StoredValue::PostEntry` remains the sole balance-posting boundary.

## Preconditions

- Account creation requires Organization context and stored-value account-create permission.
- Every account receives a generated `21` EAN-13 account number; alternate identifiers are optional and do not replace canonical identity.
- POS issue/reload lines and redemption/refund tenders require an open POS Transaction in an open Session/Business Day.
- Gift cards may be issued and reloaded through POS in Phase 6; store credit and trade credit are not cash-funded/reloaded through POS.
- Redemption requires an active account with sufficient balance.
- Manual adjustment requires reason and approval for every adjustment under Phase 6 policy.
- Reversal must reference a prior ledger entry and post the exact opposite signed amount.

## Records read

- Organization, Store, actor Membership/Permission records, and approver authorization when applicable.
- Stored Value Account and prior Stored Value Entries.
- POS Transaction, POS Line Item, POS Tender, Tender Type, and original tender/line records for linked returns or reversals.
- Post-void eligibility checks read later redemptions where reversing a positive POS-originated credit may be blocked.

## Records created or changed

- `StoredValue::CreateAccount` creates an account and canonical account number.
- `StoredValue::ResolveAccount` reads account identifiers without changing records.
- `Pos::AddStoredValueLine` creates a pending POS stored-value issue/reload line.
- `Pos::AddStoredValueTender` creates a pending redemption tender after locking/finalizing return residuals as needed.
- `Pos::AddStoredValueRefundTender` creates a pending refund tender restoring an original stored-value tender or issuing eligible store credit.
- `StoredValue::PostEntry` appends the authoritative ledger entry and updates cached balance atomically.
- `StoredValue::AdjustBalance` records a required approval and posts a `manual_adjustment` entry through `PostEntry`.
- `Pos::CompleteTransaction` posts POS-originated issue/reload/redeem/refund entries atomically with the completed POS transaction.
- `Pos::PostVoidTransaction` posts reversal entries rather than editing originals.

## Transaction boundary

Standalone account creation, manual adjustment, and ledger posting each own explicit transactions. POS-originated stored-value entries are posted inside the enclosing POS completion or post-void transaction, so transaction completion, tenders/lines, receipt numbering, inventory effects, and stored-value ledger entries commit together or not at all.

## Locks

- Account creation locks the stored-value identifier sequence.
- `StoredValue::PostEntry` locks the Stored Value Account.
- `StoredValue::AdjustBalance` locks the Account and rechecks posting-key uniqueness.
- POS stored-value line/tender services lock the POS Transaction, and tender paths lock the Account before confirming balance-sensitive changes.
- Post-void locks original/reversing POS records and affected Stored Value Accounts in the canonical cross-domain reversal order.

## Status transitions

Phase 6 account statuses are:

```text
active → suspended   (status exists; operational workflow deferred)
suspended → active   (status exists; operational workflow deferred)
```

`depleted` is derived from balance and is not a persisted status. `closed` and `replaced` are deferred.

## Ledger or snapshot effects

- Ledger entry types are `issued`, `reloaded`, `redeemed`, `refunded`, `manual_adjustment`, and `reversal`.
- Positive signed entries add value; negative signed entries consume value.
- The ledger is authoritative; cached balance is updated atomically with each entry.
- Reversal entries link to the exact original entry and carry the exact opposite amount.
- POS completed lines/tenders retain historical snapshots; later account or policy changes do not reinterpret completed activity.
- Stored-value issuance creates liability and is not ordinary merchandise revenue; redemption is tender, not a discount.

## Permissions and approvals

Implemented permission keys include `stored_value.account.view`, `stored_value.ledger.view`, `stored_value.account.create`, `stored_value.account.suspend`, `stored_value.issue`, `stored_value.reload`, `stored_value.tender.redeem`, `stored_value.tender.refund`, `stored_value.adjustment.create`, `stored_value.adjustment.approve`, and `stored_value.adjustment.approve_self`.

Manual adjustment always requires approval in Phase 6. Replacement and transfer permissions remain deferred.

## Failure behavior

- Permission, inactive/suspended account, insufficient balance, invalid entry type, invalid POS state, or missing approval failures roll back the service transaction.
- POS completion failure rolls back stored-value entries along with POS, inventory, tender, tax, and receipt-number effects.
- Post-void blocks conservative cases where a positive POS-originated credit has later redemption activity.
- Corrections never edit or delete existing ledger entries.

## Idempotency behavior

- `StoredValue::ResolveAccount` is read-only/idempotent.
- `StoredValue::PostEntry` is idempotent by posting key.
- `StoredValue::AdjustBalance` is idempotent by posting key because it delegates posting to `PostEntry` after recheck.
- POS completion and post-void use their own completion idempotency keys for the whole cross-domain transaction.
- Account creation and POS add-line/add-tender actions are not idempotent without caller-level request guards, except where card-tender request UUID handling is explicitly documented for card activity.

## Governing ADR references

- [ADR-0002](../adr/0002-canonical-identifiers-and-namespaces.md) — `21` stored-value account namespace.
- [ADR-0008](../adr/0008-immutable-pos-transactions.md) — corrections use new records.
- [ADR-0009](../adr/0009-atomic-idempotent-pos-completion.md) — POS completion atomicity/idempotency.
- [ADR-0011](../adr/0011-permissions-authority-and-approvals.md) — approval separation.
- [ADR-0012](../adr/0012-stored-value-ledger.md) — append-only authoritative ledger.

## Unresolved details

- Suspend/unsuspend status is present but operational workflow/UI remains deferred.
- Account replacement, transfer, expiration, and customer identity requirements remain deferred.
- Buyback issuance of trade credit remains outside current scope.
- Processor settlement, chargebacks, and reconciliation integrations remain Phase 7+ concerns.
