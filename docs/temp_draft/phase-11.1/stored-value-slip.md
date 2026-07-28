# POS Printing — Stored-Value Activity Slip — v1

**Status:** Draft
**Scope:** Stored-Value Activity Slip for Issuance, Reload, and Refund-to-Account
**Tracked as:** DWR-017 residual — "dedicated SV issue/reload slip"
**Not in this document:** Redemption/Manual Adjustment/Reversal Activity Slips, Balance Inquiry Slip — see [§8 Deferred](#8-deferred). Credit Voucher is covered separately in `stored-value-credit-voucher-v1.md`.

---

## 1. Purpose

Defines the printed Activity Slip for a completed Stored-Value Ledger Entry: an informational record of what happened to a Gift Card or Store Credit account, not a redeemable credential.

Printing is a presentation layer only. It does not post a Ledger Entry, change an Account balance or status, or create value.

## 2. Why v1 stops here

DWR-017 tracks exactly one Stored-Value document: a slip for issue and reload. This document covers that, plus Refund-to-Account, because Store Credit refunds have no physical card to hand the customer — the slip is the only record they get. Everything else in the original draft is real, well-designed work, but it's scope beyond what's currently tracked:

- **Credit Voucher** is an entirely separate document type — a bearer instrument with its own EAN-13 barcode, its own eligibility rules (suspended-account block), and its own permission. It isn't named in DWR-017 at all. It deserves its own spec and its own scheduling decision, not silent inclusion here.
- **Redemption Activity Slip** is largely redundant: redemption is a Tender, and the Customer Receipt (from the receipts v1 spec) already shows tenders line by line, including a Stored-Value tender. A customer doesn't need a second document for something already on their receipt.
- **Manual Adjustment and Reversal slips** are back-office corrections, not ordinary customer-facing flows, and don't currently have a UI trigger to print from.
- **Store Credit / Trade Credit reload** titles describe activity the system can't currently produce — Phase 6 policy only permits Gift Card reload through POS.

## 3. Terminology

**Activity Slip** — an informational document for one completed Stored-Value Ledger Entry. Not a bearer instrument; it never carries a redeemable credential.

**Account** — a `StoredValueAccount` (Gift Card, Store Credit, or Trade Credit). Every account has an immutable canonical Account Number (`21` EAN-13) and an append-only Ledger.

**Entry** — a `StoredValueEntry`: one signed, immutable posting to an Account's Ledger.

**Historical balance** — the Account balance immediately after the Entry the slip documents. Never the Account's current balance.

## 4. Core invariants

1. An Activity Slip documents exactly one completed Ledger Entry.
2. The canonical Account Number is masked (`Account **** 6789`) — never printed in full, never barcoded.
3. The slip shows the historical balance immediately after the Entry, not the current Account balance. A later reprint shows the same historical balance even if the Account has since changed.
4. Entry amounts print as a positive number with a directional label (`Reload amount`, `Refund amount`) — never a bare signed number.
5. A reprint is marked `REPRINT` and retains the original Entry timestamp and historical balance.
6. Printer or rendering failure never changes the Account, Ledger, related Transaction, or Tender.

## 5. Required content

1. Store header
2. Activity title (Account Type + activity — see §6)
3. `REPRINT` banner where applicable
4. Entry timestamp
5. Related Receipt Number, where the Entry came from a completed POS Transaction
6. Customer-facing Account Type label (`Gift Card`, `Store Credit`)
7. Masked Account Number
8. Activity amount, positive with directional label
9. Historical balance immediately after the Entry
10. Current informational footer

```
             SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

********* GIFT CARD RELOAD **********

Receipt MAIN-000184
Jul 27, 2026  3:42 PM

Account type: Gift Card
Account **** 6789

Reload amount                     $25.00
Balance after reload              $42.50

This slip records completed activity.
The Stored-Value Ledger is authoritative.
```

## 6. In-scope activity titles

| Entry type (as posted) | Title | Balance label |
|---|---|---|
| `issued` (Gift Card) | `GIFT CARD ISSUED` | Balance after issuance |
| `reloaded` (Gift Card only — see §2) | `GIFT CARD RELOAD` | Balance after reload |
| `refunded` (Store Credit) | `STORE CREDIT REFUND` | Balance after refund |

## 7. Deriving the historical balance

No schema addition is required. The historical balance is the sum of all Entries for the Account, through and including the selected Entry, ordered `created_at ASC, id ASC` (the Ledger's own authoritative order).

```ruby
StoredValue::BalanceAfterEntry.call(entry:)
# => StoredValue::BalanceAfterEntry::Result.new(entry:, balance_cents: 4_250)
```

Do not add `balance_after_cents` to `stored_value_entries` for v1 — the Ledger already supports deriving it, and adding a persisted snapshot is a Stored-Value domain schema decision, not a printing one.

## 8. Deferred

| Item | Why |
|---|---|
| Redemption Activity Slip | Redundant with the Stored-Value tender line already shown on the Customer Receipt. |
| Manual Adjustment / Reversal slips | Back-office activity with no current print trigger in the UI; revisit if an admin workflow needs one. |
| Store Credit / Trade Credit reload | Not reachable under current Phase 6 POS policy — only Gift Card reload posts through POS today. |
| Balance Inquiry Slip | Was already marked deferred in the original draft; nothing here changes that. |

## 9. Permissions

No permission in the accepted Phase 6 namespace (`stored_value.account.*`, `stored_value.issue`, `stored_value.reload`, `stored_value.tender.*`, `stored_value.adjustment.*`) currently covers printing. A dedicated print permission needs to be proposed against `docs/domains/stored-value.md`, not assumed:

```
stored_value.activity.print
```

Until that's accepted, the safest default is to gate the immediate print action behind the same permission that performed the activity (`stored_value.issue` / `stored_value.reload` / `stored_value.tender.refund`), and gate historical reprint behind `stored_value.account.view` — both already exist. This needs sign-off before implementation, not just this document.

## 10. Sensitive information — never printed

Full Account Number, Alternate Identifier, Account database ID, Approval PIN or credentials, authorization limits, internal Posting Key, internal adjustment codes not meant to be customer-facing, Customer contact information.

## 11. Original/reprint rules

Printed from the immediate workflow that posted the Entry (POS completion workspace) → original. Printed after retrieving Account or Entry history → `REPRINT`, retaining the original Entry timestamp and historical balance.

## 12. Acceptance criteria

1. A slip prints only from a completed, persisted Ledger Entry.
2. The Account Number never appears unmasked.
3. The printed amount is positive with a directional label, not a bare signed value.
4. The printed balance is the historical balance after the Entry, unaffected by later Account activity — verified by reprinting after a subsequent Entry and confirming the number doesn't change.
5. A reprint shows `REPRINT`, the original Entry timestamp, and the same historical balance as the original print.
6. No Ledger Entry, Account, Transaction, or Tender is created or changed by printing, reprinting, or a rendering failure.
7. Refund-to-Store-Credit slip prints even when the Entry has no related POS Transaction (administrative refund), omitting the Receipt Number rather than failing.
