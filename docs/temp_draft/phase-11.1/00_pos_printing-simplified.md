# POS Printed Documents — v1 (Customer, Gift, Post-Void Receipts)

**Status:** Background — superseded as governing plan by [phase-11.1-pos-printed-documents-v1.md](../../implementation/phases/phase-11.1-pos-printed-documents-v1.md)  
**Scope:** Customer Receipt, Gift Receipt, Post-Void Receipt  
**Not in this document:** Cash Movement Slips, Credit Vouchers / Stored-Value Activity Slips, X and Z Reports — see [§9 Deferred](#9-deferred).

Longer research drafts in this folder remain background. Prefer the promoted phase plan for delivery status, gates, and issue links; this file retains the detailed build-contract language used during design.

---

## 1. Purpose

Defines what ShelfStack prints for a completed POS Transaction: the Customer Receipt, the Gift Receipt, and the Post-Void Receipt.

This is a presentation layer only. It does not complete a Transaction, post a Cash Movement, adjust Stored Value, reverse a Transaction, or change Inventory. A print or render failure never rolls back or invalidates already-completed activity.

## 2. Why v1 stops here

Every fact in this document already exists on a completed `pos_transactions` record per `docs/domains/point-of-sale.md` (Receipt Number, completion timestamp, cashier, lines, tax, tenders, Post-Void relationships). No new domain concept, numbering scheme, or schema addition is required beyond one configuration field (§8 / §18).

Cash Movement Slips and X/Z Report printing are deferred because they depend on domain decisions that don't exist yet or are incomplete (Cash Movement identity; the missing Business-Day X Report in the reporting taxonomy). Stored-Value documents are well-grounded in `docs/domains/stored-value.md` but are sequenced after this smaller, self-contained slice to validate the shared header/barcode/reprint components first.

## 3. Terminology

**Document** — a structured presentation derived from a completed source record.

**Original** — printed from the immediate workflow that completed the source record (the Receipt workspace right after checkout, or the immediate Post-Void completion workspace). Multiple copies from that workspace all remain originals. Original vs reprint is **server-owned** (§13).

**Reprint** — printed after the source record was retrieved through Receipt Lookup, Transaction history, Customer history, or any other later workflow. Always marked `REPRINT`. A caller-supplied query parameter must not be able to suppress it.

## 4. Core invariants

1. Documents are generated only from completed Transactions.
2. Historical amounts, tax, and totals are never recalculated from current Product/Pricing/Tax configuration — only current Store header/footer/labels may be resolved at print time.
3. A reprint keeps the original Receipt Number; it never gets a new one.
4. A reprint is visibly marked `REPRINT` near the top, with original and reprint timestamps.
5. A reprint of a Post-Voided original is marked `VOIDED` and references the reversing Receipt Number.
6. Price Overrides are never identified on a Customer Receipt — the overridden price prints as the ordinary item price, with no regular-price comparison, override reason, or authorizing user.
7. Discounts always print as explicit reductions, distinct from Price Overrides.
8. A barcode is always accompanied by its human-readable reference. No internal database ID is ever printed or encoded.
9. When a Customer is attached, Customer identity on the Customer Receipt is limited to a masked Customer Number (`Customer **** 4837` — last four of `customer_number`). Never print full number, name, address, phone, email, or internal Customer ID. When no Customer is attached, omit the line. No Store preference flag in v1.
10. Missing current configuration (renamed/deactivated Store field, missing logo) degrades to a safe fallback label; it never blocks printing.

## 5. Customer Receipt

### 5.1 Required content

- Store header (name, address, phone, current `receipt_header`)
- Receipt/Transaction Number, human-readable, plus barcode (§14)
- Completion timestamp
- Register and cashier
- Masked Customer Number when a Customer is attached (§15); omit when none
- Completed lines: description, quantity, selling price (overridden price shown as ordinary price)
- Discounts, as explicit reductions
- Tax summary (label, rate, amount)
- Transaction total
- Completed tenders, refunds, cash change
- Original Receipt reference, if this Transaction includes a linked Return
- Current `receipt_footer`

### 5.2 Presentation rules

- A mixed sale-and-return Transaction marks individual return lines; it does not banner the whole receipt `RETURN`.
- Overridden price example:

  ```
  THE LEFT HAND OF DARKNESS
  1 × $19.99                         $19.99
  Member discount                    -$2.00
  ```

  Never:

  ```
  Regular $24.99 → Override $19.99
  ```

### 5.3 Fact sources (no schema change required)

| Fact | Source |
|---|---|
| Receipt Number | `pos_transactions.receipt_number` |
| Completion timestamp | `pos_transactions.completed_at` |
| Cashier | `pos_transactions.cashier_user` |
| Register | completed session's POS Device |
| Customer | `pos_transactions.customer` (masked number only — §15) |
| Lines, tax, tenders | completed line/tax-component/tender records |

**Presentation gap on main today:** `customer_receipt` prints Customer name and full `customer_number`. This slice must mask per §15.

## 6. Gift Receipt

A brief, price-suppressed lookup summary — not an itemized receipt, not a return authorization, not a bearer credential, not a separate database record.

### 6.1 Required content

- Store header
- `GIFT RECEIPT` title
- Receipt/Transaction Number, human-readable, plus barcode
- Completion date and time
- Store, Register, cashier (lookup context)
- Current `stores.gift_receipt_footer`

### 6.2 Prohibited content

Item lines, prices, discounts, totals, tax, tenders, purchaser identity, return-eligibility claims, any separate Gift Receipt number, any token.

```
           SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

************ GIFT RECEIPT ************

Receipt 01-00018425
Jul 27, 2026 3:42 PM
Store MAIN · Register 02
Cashier Jordan

[receipt lookup barcode]
01-00018425

This Gift Receipt may be used to locate
the original Transaction. Returns remain
subject to Store policy and verification.
```

### 6.3 Original/reprint

Printed from the immediate completion workflow → original. Printed after retrieving the historical Transaction → `REPRINT`. No token, no expiration, no revocation state — none of that exists in the current model and none is needed.

A Gift Receipt for a Transaction that has since been Post-Voided must show `VOIDED` (and may still barcode the original Receipt Number for lookup).

No Gift Receipt action appears on a reversing Post-Void Transaction (§12).

## 7. Post-Void Receipt

### 7.1 Required content (customer-facing — v1 Must)

- `POST-VOID` title
- Reversing Receipt Number, human-readable, plus barcode
- Original Receipt Number and its completion timestamp
- Reversal completion timestamp
- Reversing lines, discounts, tax, tenders (the exact reversed values, not recalculated)
- Current Store footer

### 7.2 Customer copy omits

Internal Post-Void reason, authority thresholds, approval credentials, internal eligibility checks, Inventory / Product Request reversal detail.

### 7.3 Reprint of the original after Post-Void (v1 Must)

```
VOIDED

Receipt 01-00018425
Reversed by receipt 01-00018502
Reversal completed Jul 27, 2026 4:18 PM
```

The original Transaction's stored facts are never rewritten — this is a correction notice, not an edit.

### 7.4 Internal Post-Void copy

See [§16](#16-post-void-customer-vs-internal).

## 8. Configuration addition

One field, confirmed necessary and sufficient for this scope:

```
stores.gift_receipt_footer :text
```

No other schema change is required. No Receipt snapshot, stored HTML/PDF, print-event audit table, Gift Receipt token/entitlement table, or separate Gift Receipt Number is needed.

Admin surface: [§18](#18-configuration-and-admin).

## 9. Deferred

| Document | Why it's not in v1 |
|---|---|
| Cash Movement Slip | Depends on a Cash Movement identity/numbering scheme that doesn't exist yet in `point-of-sale.md`. That's a POS-domain schema decision and should be proposed there (with its own review), not invented inside a printing spec. |
| Credit Voucher / Stored-Value Activity Slip | Well-grounded in `docs/domains/stored-value.md` (entry types, account types, ledger balance all exist today) — good candidate for the next document after this one lands, not blocked by anything. |
| X and Z Reports | The reporting domain defines four report types (Session X, Session Z, Business-Day X, Business-Day Z); a full report-printing spec needs to cover all four, including the Business-Day X snapshot, before it's complete. |
| INV-POS-014 print-event audit table | Not required for browser print; remains DWR-017 residual. |
| ESC/POS / printer fleets | Outside Phase 11.1; browser print only. |

## 10. Permissions

See the locked table in [§19](#19-permissions). Exact keys live in `docs/domains/authorization-permissions.md`. This document does **not** invent `pos.gift_receipt.*` or other new permission codes for MVP.

## 11. Acceptance criteria

1. A completed Transaction renders without consulting current Pricing or Tax services.
2. Changing the current Store header/footer/gift footer changes future prints without changing historical amounts.
3. A reprint retains the original Receipt Number and is visibly marked `REPRINT`.
4. Printing from the immediate completion workspace is never marked `REPRINT`.
5. A Price Override never appears identified on a Customer Receipt; the overridden price prints as the ordinary price.
6. Discounts always print as explicit reductions.
7. A Gift Receipt contains only header, lookup data, barcode, human-readable reference, and footer — nothing else.
8. A Post-Void Receipt shows both original and reversing Receipt Numbers.
9. A reprint of a Post-Voided original shows `VOIDED` and the reversing Receipt reference.
10. No internal database ID appears on any printed or barcoded output.

Implementable checks are expanded in [§20](#20-implementation-acceptance--tests).

---

## 12. Entry points

| Screen / context | Actions | Document | Original vs reprint |
| --- | --- | --- | --- |
| Immediate Receipt workspace (after complete) | Print Receipt, Print Gift Receipt, Next transaction | Customer / Gift | **Original** (server-owned immediate context) |
| Receipt Lookup / historical completed txn | Reprint Receipt, Reprint Gift Receipt, Start Return | Customer / Gift | **Reprint** (requires `pos.receipt.reprint`) |
| Post-Voided original (historical) | Reprint Receipt, Reprint Gift Receipt, View reversing | Customer / Gift | Reprint + **VOIDED** |
| Reversing Post-Void txn | Print / Reprint Post-Void Receipt, View original | Post-Void | Original if immediate after post-void; else Reprint. **No Gift Receipt** |

UI home for completion actions: extend `app/views/pos/receipt/_commands.html.erb` / overflow. On main today, only Customer Print / Reprint exist.

## 13. Server-owned print context and routes

Original versus reprint must **not** be controlled solely by a client query parameter. On main today, `PosTransactionsController#customer_receipt` sets `@reprint` from `params[:reprint]` — that is a **workflow gap** this slice must close.

Required route separation (names illustrative; match Rails conventions when implementing):

```text
GET /pos_transactions/:id/customer_receipt
GET /pos_transactions/:id/customer_receipt/reprint
GET /pos_transactions/:id/gift_receipt
GET /pos_transactions/:id/gift_receipt/reprint
GET /pos_transactions/:id/post_void_receipt
GET /pos_transactions/:id/post_void_receipt/reprint
```

**Immediate (non-reprint) routes** must confirm:

- the Transaction is completed;
- the current User may view that Transaction;
- the Transaction matches a **server-owned immediate completion context** (e.g. still the open Receipt presentation for the completing session/workspace).

They never render `REPRINT`.

**Historical `/reprint` routes** must:

- require `pos.receipt.reprint`;
- always render `REPRINT` (and reprint timestamp);
- ignore attempts to suppress the marker (including stale `?reprint=false`).

An equivalent trusted server design is acceptable if it preserves the same guarantees.

## 14. Barcode

| Rule | Lock |
| --- | --- |
| Symbology | **Code 128** |
| Payload | Exact public `pos_transactions.receipt_number` string only |
| Human-readable | Always print the same Receipt Number beneath the barcode |
| Forbidden payload | Internal DB IDs, UUIDs, store/device/cashier codes, prices, customer data |
| Channel | Browser print only (no ESC/POS in this slice) |
| Implementation note | Server-rendered SVG or PNG via a Ruby barcode library (e.g. Barby). Do not introduce Node/npm for barcode generation. |

Gift and Customer and Post-Void documents use the same barcode rules for their document’s Receipt Number (reversing number on the Post-Void Receipt; original number on Gift / Customer / VOIDED original reprint).

## 15. Customer masking

When `pos_transactions.customer` is present on the Customer Receipt:

```text
Customer **** 4837
```

- Retain the final four characters of `customer_number` (unless a future Customer Number format requires another safe convention documented here).
- Never print: full Customer Number, display name, address, phone, email, internal Customer ID.
- When no Customer is attached: omit the Customer line entirely.
- Gift Receipts never show Customer identity (§6.2).
- No Store “show customer on receipt” preference in v1.

## 16. Post-Void customer vs internal

| Copy | v1 status | Content | Entry | Permission |
| --- | --- | --- | --- | --- |
| Customer-facing Post-Void Receipt | **Must** | §7.1 | Immediate after Post-Void complete, or historical reprint of reversing txn | Immediate: `pos.access` + view txn; historical: `pos.receipt.reprint` |
| VOIDED reprint of original | **Must** | §7.3 | Historical reprint of Post-Voided original | `pos.receipt.reprint` |
| Internal Post-Void record | **Should** — ship in the same slice if cheap; otherwise immediate DWR-017 follow-up | Customer copy **plus** requester, approver, reason, external card-reversal reference | Post-Void / reversing history only — **not** ordinary Receipt Print | Existing `pos.post_void.create` (do not invent a new print permission) |

## 17. Delta from Gate 11D Must

### Already on main (Phase 11 / #150)

- Browser-printable Customer Receipt (`layouts/pos_receipt`, `customer_receipt`)
- Store name / address / `receipt_header` / `receipt_footer`
- Completed line description/identifier snapshots, discounts, tax, tenders
- `REPRINT` marker path and `pos.receipt.reprint`
- Return / mixed / post-void document banners; linked original receipt reference
- Print/display does not reverse completion

### This slice adds

- Gift Receipt + `stores.gift_receipt_footer`
- Code 128 barcode + human-readable reference
- Masked Customer Number (fix name + full number on print)
- Price-override suppression on the printed Customer Receipt (unit price as ordinary price)
- Server-owned original/reprint routes (close `params[:reprint]` authority gap)
- Dedicated Post-Void Receipt template + VOIDED historical original reprint behavior
- Receipt workspace actions: Print Gift Receipt; Post-Void print/reprint actions per §12

## 18. Configuration and admin

**Schema (only addition):**

```ruby
add_column :stores, :gift_receipt_footer, :text
```

**Admin for v1:** add `gift_receipt_footer` to `StoresController` strong params (alongside existing `receipt_header` / `receipt_footer`) and expose all three text fields on the Store edit form if not already visible. Not a new settings platform.

Fuller organization/store settings UI remains [DWR-019](../../implementation/deferred-work-register.md).

Empty or missing `gift_receipt_footer` → omit footer block or show a short safe fallback; never block print (§4.10).

## 19. Permissions

| Action | Permission |
| --- | --- |
| Original Customer / Gift / Post-Void from immediate completion | `pos.access` (+ ability to view that completed Transaction) |
| Historical reprint of Customer / Gift / Post-Void | `pos.receipt.reprint` |
| Internal Post-Void copy (if shipped) | `pos.post_void.create` |
| Start Return from lookup | Existing return permissions (`pos.return.create`, etc.) |

Canonical key definitions: `docs/domains/authorization-permissions.md`. Do **not** add `pos.gift_receipt.*` for MVP.

## 20. Implementation acceptance / tests

In addition to §11, delivery should cover:

1. **Reprint authority:** Immediate routes never show `REPRINT`. Historical `/reprint` routes always show `REPRINT`. A client cannot suppress historical reprint via query params.
2. **Gift content:** Gift route response omits line items, prices, discounts, tax, tenders, and Customer identity.
3. **Customer mask:** Customer Receipt shows `Customer **** ####` when attached; never name or full number.
4. **Override suppression:** No “regular → override” or override-reason copy on the Customer Receipt; unit price prints as the completed selling price.
5. **Barcode:** Rendered barcode payload equals `receipt_number`; human-readable value appears beneath.
6. **VOIDED original:** Historical reprint of a Post-Voided original shows `VOIDED` and the reversing Receipt Number.
7. **Config freshness vs history:** Changing Store header / gift footer affects the next print; changing Tax rules after completion does not change printed amounts.
8. **Post-Void Gift ban:** Reversing Post-Void Transaction UI does not offer Print Gift Receipt.
