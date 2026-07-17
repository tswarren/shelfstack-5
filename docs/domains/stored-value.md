# Stored Value Domain

**Status:** Consolidated specification  
**Domain owner:** Gift Card, Store Credit, and Trade Credit accounts and immutable balance history

## Governing ADRs

- [ADR-0002: Use Canonical Identifiers and Separate Restricted-Circulation Namespaces](../adr/0002-canonical-identifiers-and-namespaces.md)
- [ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections](../adr/0008-immutable-pos-transactions.md)
- [ADR-0009: Complete POS Transactions Atomically and Idempotently](../adr/0009-atomic-idempotent-pos-completion.md)
- [ADR-0012: Govern Stored Value Through Independent Accounts and an Append-Only Ledger](../adr/0012-stored-value-ledger.md)

## Purpose

This domain governs customer-held value represented by:

```text
gift_card
store_credit
trade_credit
```

These types share account and Ledger infrastructure but remain distinct for policy, accounting, and reporting.

## Ownership boundary

### Owns

- Stored-Value Account;
- canonical Account Number;
- Alternate Identifier;
- account type;
- account status;
- cached current balance;
- Stored-Value Entry;
- issuance;
- reload;
- redemption;
- refund to account;
- reversal;
- manual adjustment.

### References but does not own

- POS Transaction;
- POS Line Item;
- POS Tender;
- User and Approval;
- future Customer;
- future Buyback transaction;
- report definitions.

## Stored-Value Account

Every account has a canonical generated `21` EAN-13 Account Number.

An optional Alternate Identifier may represent a preprinted card number, migrated legacy number, or external certificate reference.

Suggested attributes:

- Organization;
- account type;
- canonical Account Number;
- Alternate Identifier;
- status;
- cached current balance;
- issued timestamp;
- optional Customer;
- creation metadata.

Potential statuses:

```text
active
suspended
closed
replaced
```

The final lifecycle remains Open. `depleted` may be derived from balance rather than persisted.

## Stored-Value Ledger

The Ledger is append-only and authoritative.

Suggested Entry types:

```text
issued
reloaded
redeemed
refunded
issuance_reversed
redemption_reversed
manual_adjustment
```

Each Entry retains account, signed amount, Entry type, related POS records, reversing Entry reference where applicable, performing User, Approval and reason for manual activity, and timestamp.

Positive amounts add value. Negative amounts consume value.

The cached balance updates atomically with a new Entry.

## POS interactions

### Issuance

A Gift Card issuance is a POS Stored-Value sale line funded by ordinary Tender.

It creates liability, not ordinary merchandise revenue.

### Reload

A reload adds value to an existing account and is funded by ordinary Tender.

Which account types may reload remains policy-specific.

### Redemption

Redemption is a received Tender.

It reduces account balance and liability.

It is not a Discount, negative revenue, or tax adjustment.

### Refund to Stored Value

A refunded Stored-Value Tender increases the account balance.

Gift-receipt and no-receipt Returns may issue Store Credit.

### Mixed original Tenders

For linked Returns, Stored Value is restored before applicable external Tender methods under the established refund policy.

## Atomicity

Related POS and Stored-Value activity commits atomically.

A Completed Stored-Value Line or Tender must have its required Ledger Entry.

A Ledger Entry must not post without its completed originating POS activity, except an authorized manual adjustment.

## Manual adjustments

Manual adjustment requires Permission, reason, performing User, and Approval where policy requires.

It creates a new Entry and never overwrites history.

## Reversal

A correction creates reversing Entries.

Post-Void of issuance may be blocked after any issued value has been redeemed.

The original Entry remains intact.

## Permissions

```text
stored_value.view_balance
stored_value.view_ledger
stored_value.issue
stored_value.reload
stored_value.redeem
stored_value.refund
stored_value.adjust
stored_value.suspend
stored_value.replace
```

## Audit requirements

Audit account creation, issuance, reload, redemption, refund, manual adjustment, suspension, replacement, reversal, blocked reversal, performing and approving Users, and related POS records.

## Reporting requirements

Reports distinguish Gift Card, Store Credit, and Trade Credit, and distinguish issued, reloaded, redeemed, refunded, reversed, and manually adjusted activity.

Stored-Value issuance is excluded from ordinary sales revenue.

## Buyback boundary

Buyback is Deferred and is not defined as part of the current Stored-Value schema.

A future Buyback workflow may issue Trade Credit, but it also requires seller identity, merchandise evaluation, Product and Variant resolution, Inventory-Unit creation, acquisition cost, cash payout, and legal and Approval requirements.

Buyback is acquisition, not Customer Return.

## Invariants

- Account types remain distinct.
- Every account has one canonical `21` EAN-13 number.
- Alternate Identifier does not replace canonical identity.
- Ledger Entries are append-only.
- Ledger is authoritative.
- Cached balance reconciles to Ledger.
- Issuance creates liability.
- Redemption is Tender.
- Redemption does not exceed available balance unless a later policy permits it.
- POS and Stored-Value posting are atomic.
- Corrections create reversing Entries.
- Manual adjustment is authorized and reasoned.

## Open questions

- What is the final account-status model?
- Which account types may reload or transfer?
- Is Customer identity required for Store Credit or Trade Credit?
- What replacement and credential model is required?
- Are expiration dates supported?
- What legal jurisdiction rules apply?
- What adjustment threshold requires Approval?
- How will Buyback create Trade Credit?
