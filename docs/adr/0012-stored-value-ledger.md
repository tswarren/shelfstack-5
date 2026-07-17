# ADR-012: Govern Stored Value Through Independent Accounts and an Append-Only Ledger

**Status:** Accepted

## Context

ShelfStack must support:

* gift cards;  
* store credit;  
* trade credit.

These values may originate through different workflows but share common requirements:

* account lookup;  
* balance validation;  
* issuance;  
* redemption;  
* refund;  
* reversal;  
* adjustment;  
* audit.

Stored value is not ordinary merchandise inventory.

Issuance is not ordinary revenue.

Redemption is not a discount.

A mutable balance without a ledger would not provide sufficient audit history.

## Decision

ShelfStack will represent stored value through:

1. a stored-value account;  
2. an append-only stored-value ledger.

## Account types

Initial account types are:

```
gift_card
store_credit
trade_credit
```

These types may share technical infrastructure but remain distinct for:

* policy;  
* reporting;  
* accounting;  
* customer communication;  
* redemption rules.

## Account identity

Every stored-value account receives a canonical generated `21` EAN-13 identifier.

The account may also contain an alternate identifier.

The canonical identifier is:

* organization-wide;  
* unique;  
* immutable;  
* never reused;  
* scannable.

The alternate identifier may represent:

* a preprinted card;  
* a migrated card;  
* an external certificate;  
* another approved reference.

## Ledger entries

The stored-value ledger is append-only.

Potential entry types include:

```
issued
reloaded
redeemed
refunded
issuance_reversed
redemption_reversed
manual_adjustment
```

Entries record signed amounts:

* positive values add stored value;  
* negative values consume stored value.

Corrective activity creates a new reversing entry.

Existing entries are not changed.

## Cached balance

The account may store a cached current balance for performance.

The ledger remains the authoritative balance history.

The cached balance must be updated atomically with ledger posting.

## POS treatment

### Issuance

A gift-card issuance is a stored-value POS sale line.

The customer pays using an ordinary tender.

The activity creates a liability rather than ordinary merchandise revenue.

### Reload

A reload adds value to an existing account and is funded by ordinary tender.

### Redemption

Redemption is a received tender.

It reduces the stored-value balance and liability.

It is not:

* a discount;  
* negative revenue;  
* a tax reduction.

### Refund

A refund to store credit or another stored-value account increases the account balance.

### Return restoration

When a linked return relates to an original mixed-tender transaction, stored value is restored before external tender methods, according to the established refund policy.

## Atomicity

The stored-value ledger entry and its related completed POS activity must commit together.

A completed POS line or tender must not exist without its required stored-value entry.

A stored-value entry must not post without its completed originating activity, except for an explicitly authorized manual adjustment.

## Manual adjustments

Manual adjustments require:

* permission;  
* reason;  
* performing user;  
* approval where required.

They create new ledger entries.

They do not overwrite account history.

## Consequences

### Benefits

* Preserves complete balance history.  
* Separates liability activity from revenue.  
* Supports gift cards, store credit, and trade credit consistently.  
* Supports scanning of generated account numbers.  
* Supports migrated or preprinted cards.  
* Enables exact reversal and audit.

### Costs

* Cached balance and ledger must remain synchronized.  
* Replacement and credential management may require later extension.  
* Expiration, transfer, and legal rules remain to be designed.  
* Atomic POS integration is required.

## Alternatives considered

### Store only the account balance

Rejected because it would not preserve transaction history.

### Treat stored-value redemption as a discount

Rejected because it is a method of settlement.

### Treat gift-card issuance as sales revenue

Rejected because it creates an obligation to provide future value.

### Use the alternate card number as the sole account identity

Rejected because ShelfStack requires one stable canonical account reference.

## Deferred extensions

The following are not decided by this ADR:

* account expiration;  
* card replacement;  
* several credentials for one account;  
* account transfers;  
* digital wallet credentials;  
* escheatment handling;  
* legal jurisdiction rules.

A later credential table may be introduced when one account must support several physical or digital access identifiers.

## Governing rules

* Stored-value entries are append-only.  
* The ledger is authoritative.  
* The cached balance must reconcile to the ledger.  
* Issuance creates liability.  
* Redemption is tender.  
* POS and stored-value posting are atomic.  
* Canonical `21` identifiers are immutable and never reused.  
* Gift card, store credit, and trade credit remain separately reportable.

## Related domains

* Stored Value  
* Point of Sale  
* Reporting and Reconciliation  
* Future Buyback domain
