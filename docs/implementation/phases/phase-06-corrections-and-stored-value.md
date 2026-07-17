# Phase 6 — Corrections and Stored Value

**Status:** Not started  
**Depends on:** Phase 4c; Phase 4e helpful for return/refund patterns  
**Unlocks:** liability and correction reporting in Phase 7  
**Governing docs:** ADR-0008, ADR-0012; [stored-value](../../domains/stored-value.md); [point-of-sale](../../domains/point-of-sale.md)

## Goal

Correct completed activity with linked reversing records, and govern gift card / store credit / trade credit through an append-only ledger.

## Corrections

- Post-void as a new completed transaction reversing an earlier completed transaction (copy original commercial facts; do not recalculate from current config).
- Refund tenders; inventory reversals; stored-value reversals.
- Never edit, delete, or reclassify completed sale lines in place.

## Stored value

### Tables

- `stored_value_accounts` (`21` EAN-13 canonical identifiers; optional alternate lookup)
- `stored_value_entries` (append-only ledger)
- `stored_value_adjustment_reasons` (as needed)

### Behavior

- Account types remain separately reportable: gift card, store credit, trade credit.
- Ledger is authoritative; cached balance optional.
- Issuance creates liability, not ordinary merchandise revenue.
- Redemption is tender, not a discount.
- Issuance, reload, redemption, refund, adjustment, and reversal post atomically with related POS activity.

## Exit criteria

- [ ] Post-void reverses inventory, tenders, and totals without mutating the original transaction
- [ ] Gift-card issue + redeem commits atomically with POS
- [ ] Ledger entries are immutable; corrections add reversing entries
- [ ] Idempotent completion still holds when stored value participates

## Out of scope

- Stored-value replacement, transfer, and expiration ([deferred](../deferred-capabilities.md))
- Integrated payment processor beyond stubs

## Related

- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
- [../deferred-capabilities.md](../deferred-capabilities.md)
