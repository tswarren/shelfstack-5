# POS Printing — Credit Voucher — v1

**Status:** Draft
**Scope:** Credit Voucher for Gift Card, Store Credit, and Trade Credit accounts
**Companion document:** `stored-value-activity-slip-v1.md`
**Not currently tracked:** this document is not named in DWR-017 today — adding it means registering it as new tracked scope, not just writing the spec (see §9).

---

## 1. Purpose

A Credit Voucher is a printed bearer instrument representing one Stored-Value Account's credential: its canonical Account Number, exposed in full, plus its current balance at print time.

This is fundamentally different from the Activity Slip. The Activity Slip documents a past event and masks the Account Number. The Voucher *is* the credential — anyone holding it can present it for redemption, the same way anyone holding a gift card can. Treat every design decision below with that in mind.

Printing a Voucher does not create, transfer, increase, or decrease value. It does not post a Ledger Entry.

## 2. Why this matters for Store Credit and Trade Credit specifically

Gift Cards usually have a physical card the customer already holds — the Voucher is a convenience or replacement. Store Credit and Trade Credit have no physical card by default: the account only exists in ShelfStack. The Voucher is often the *only* thing a customer can walk away with after a Store Credit refund. That's the real justification for building this now rather than deferring it further.

## 3. Core invariants

1. A Voucher represents one Stored-Value Account, not one Ledger Entry — it's generated from the Account, not from a Transaction or Entry.
2. The full canonical Account Number (`21` EAN-13) is printed and barcoded. This is the one stored-value document where that's correct.
3. The Alternate Identifier, if the account has one, is never the printed credential and does not print by default — only the canonical Account Number.
4. The balance shown is the *current* Account balance at print time, not a historical balance. It is explicitly informational — printing does not reserve or guarantee it still being available later.
5. Multiple printed copies represent the same Account and the same one balance. Printing a copy never creates value, never posts an Entry, never changes status.
6. An active Account with a zero balance may still be printed — zero balance is not suspension, and the account may be reloaded later. (Gift Card only, per current reload policy — see the Activity Slip doc §2.)
7. A suspended Account may not be printed as an ordinary redeemable Voucher (see §5). This is a presentation-layer eligibility check built on the existing `active`/`suspended` status field — it does not introduce new Stored-Value domain state.
8. Printer or rendering failure never changes the Account or Ledger.

## 4. Required content

1. Store header
2. `CREDIT VOUCHER` title
3. `REPRINT` banner where applicable
4. Account Type (`Gift Card`, `Store Credit`, `Trade Credit`)
5. Current Account balance
6. Balance-as-of timestamp
7. Full canonical Account Number
8. EAN-13 barcode encoding that exact number
9. Human-readable Account Number beneath the barcode
10. Bearer warning
11. Statement that the current ShelfStack balance and status control redemption

```
             SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

************ CREDIT VOUCHER ***********

Account type: Store Credit

Current balance                   $18.75
Balance as of Jul 27, 2026 4:18 PM

Account 2100123456789

[EAN-13 BARCODE]
2100123456789

Treat this voucher like cash.
Possession may permit use of the associated
Stored-Value Account.

The current ShelfStack balance and Account
status control redemption.
```

## 5. Suspended accounts

An ordinary redeemable Voucher must not be printed for a suspended Account. The application shows:

```
This Stored-Value Account is suspended and
cannot be printed as a redeemable Credit Voucher.
```

A newly printed bearer instrument for an account that currently can't be redeemed would be actively misleading — this isn't optional politeness, it's the difference between a useless slip and a document someone might reasonably expect to spend. Historical Activity Slips remain unaffected (covered in the companion document) — this restriction is Voucher-only.

Existing paper copies printed before suspension can't be recalled. Redemption stays controlled by the Account's live status regardless of what any paper copy says — the Voucher was never authoritative, only a snapshot.

## 6. Barcode

The canonical Account Number is already a valid EAN-13 identifier, so the Voucher barcode is EAN-13 — no new symbology decision needed here, unlike the receipt-number barcode question in the receipts spec.

Must encode only the canonical Account Number. Must not encode a database ID, Ledger Entry ID, Transaction UUID, Customer ID, or the Alternate Identifier.

If barcode generation fails, the Voucher still prints with the human-readable Account Number prominent and a visible (non-blocking) warning. Manual entry fallback is acceptable for v1.

## 7. Sensitive information — never printed

Alternate Identifier (by default), Account database ID, Ledger Entry IDs, internal Approval details, internal Posting Keys, Customer contact information.

## 8. Original/reprint rules

**Original:** printed from the immediate workflow associated with issuance, a refund that creates or credits an account, or another authorized immediate Stored-Value workflow.

**Reprint:** printed from Account history, Receipt history, or Stored-Value administration. Shows `REPRINT`, the current balance and status *at reprint time* (not the original issuance balance), and the same unchanged Account Number. `REPRINT` does not imply the account is invalid — it's still a live credential, just printed again later.

## 9. What adding this actually requires

Two things beyond the spec itself, both real decisions, not implementation detail:

1. **Registering the work.** DWR-017 currently tracks only the Activity Slip ("dedicated SV issue/reload slip"). Credit Voucher needs to be added to that register entry (or its own entry) before it's treated as scheduled work — otherwise it's speced but not on anyone's plan.
2. **A dedicated permission.** Because this document exposes a redeemable bearer credential — unlike everything else in the printing spec, which only exposes historical facts — it needs authority separate from ordinary receipt or activity-slip printing. Proposed, not yet accepted:

   ```
   stored_value.voucher.print
   ```

   Requires: access to the Account, and `stored_value.voucher.print`. Ordinary `pos.receipt.reprint` or `stored_value.account.view` must not be sufficient on their own — printing a Voucher is closer in risk to handing someone a blank check than to reprinting a receipt, and the permission should say so. This needs the same sign-off path as the Activity Slip's proposed `stored_value.activity.print` — both are new entries against `docs/domains/authorization-permissions.md` and `stored-value.md`, not settled facts yet.

## 10. Explicitly deferred (unchanged from original scope)

Balance Inquiry Slip, Voucher cancellation independent of Account suspension, historical Voucher facsimiles, Alternate Identifier printing, multilingual templates, Store-specific Voucher terms beyond fixed wording, email/SMS delivery, online balance portal.

## 11. Acceptance criteria

1. Voucher prints only for an `active` Account; a `suspended` Account produces the eligibility message instead, with no document generated.
2. The full canonical Account Number appears in both barcode and human-readable form; no other identifier is encoded.
3. The printed balance is the current balance at print time, confirmed by comparing two prints taken before and after an intervening Entry — the second print shows the new balance.
4. Printing two copies of the same Voucher creates no second Entry, no balance change, and no status change.
5. A zero-balance active Account can still produce a Voucher, printing `$0.00` without implying value is available.
6. A reprint shows `REPRINT`, current balance and status at reprint time, and the unchanged Account Number.
7. Barcode failure leaves the Voucher printable with a visible warning and a prominent human-readable number.
8. A user without `stored_value.voucher.print` cannot print a Voucher even if they can view the Account.
