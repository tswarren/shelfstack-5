# Phase 11.1 — POS printed documents v1

**Status:** In progress — gates 11.1A–D complete (epic [#151](https://github.com/tswarren/shelfstack-5/issues/151); [#152](https://github.com/tswarren/shelfstack-5/issues/152)–[#155](https://github.com/tswarren/shelfstack-5/issues/155)); reopened for 11.1E–F. Remains open until explicitly closed.
**Depends on:** Phase 11 closed; Phase 6 post-void and corrections; Phase 9 Customer v1
**Primary register item:** [DWR-017](../deferred-work-register.md), partially
**Source design packet:** [00_pos_printing-simplified.md](../../temp_draft/phase-11.1/00_pos_printing-simplified.md) (receipt build contract); [typography.md](../../temp_draft/phase-11.1/typography.md); [stored-value-slip.md](../../temp_draft/phase-11.1/stored-value-slip.md) (Activity Slip); [stored-value-voucher.md](../../temp_draft/phase-11.1/stored-value-voucher.md) (Credit Voucher); longer drafts under [phase-11.1/](../../temp_draft/phase-11.1/) are background
**Governing docs:** [Phase 11 — POS Shell and Workspace Revamp](phase-11-pos-shell-and-workspace-revamp.md); [Point of Sale](../../domains/point-of-sale.md); [Stored Value](../../domains/stored-value.md); [Authorization and Permissions](../../domains/authorization-permissions.md); ADR-0008; ADR-0009; ADR-0012
**Epic:** [#151](https://github.com/tswarren/shelfstack-5/issues/151)
**Gate issues:** [#152](https://github.com/tswarren/shelfstack-5/issues/152) (11.1A), [#153](https://github.com/tswarren/shelfstack-5/issues/153) (11.1B), [#154](https://github.com/tswarren/shelfstack-5/issues/154) (11.1C), [#155](https://github.com/tswarren/shelfstack-5/issues/155) (11.1D); 11.1E–F tracked under epic [#151](https://github.com/tswarren/shelfstack-5/issues/151)

---

## 1. Characterization

Phase 11.1 is a focused follow-on to Phase 11 Gate D.

Phase 11 established the completed-transaction Receipt presentation, browser-printable customer receipts, historical receipt lookup, receipt reprinting, completed-fact rendering, and basic return/mixed/post-void banners.

Phase 11.1 delivers browser-printable POS documents:

1. Customer Receipt *(delivered — gates 11.1A–D)*
2. Gift Receipt *(delivered)*
3. Post-Void Receipt *(delivered)*
4. Stored-Value Activity Slip *(11.1E — in delivery)*
5. Credit Voucher *(11.1F — in delivery)*

This phase is not a general document-generation framework.

---

## 2. Goal

Deliver reliable, privacy-conscious, browser-printable documents that:

* reproduce completed POS and Stored-Value facts without recalculation (except Credit Voucher current balance at print time);
* clearly distinguish originals, reprints, and voided activity;
* support fast transaction lookup through a receipt-number barcode;
* provide a narrowly defined non-itemized Gift Receipt;
* provide customer-facing evidence of a completed Post-Void;
* provide informational Activity Slips for issue / reload / refund-to-account;
* provide bearer Credit Vouchers for active Stored-Value Accounts;
* remain independent of transaction completion and other posting operations.

A print, render, barcode, or browser failure after successful posting must never reopen, reverse, or invalidate completed Transactions, Accounts, or Ledger Entries.

---

## 3. MVP scope

### 3.1 Customer Receipt *(delivered)*

Harden the existing Customer Receipt to include:

* current Store name, address, phone, `receipt_header`, and `receipt_footer`;
* Receipt Number with Code 128 barcode and human-readable text beneath;
* transaction completion timestamp; completed Register and cashier;
* masked Customer Number when attached (`Customer **** ####`);
* completed sale and return lines, quantities, selling prices;
* explicit discount reductions; tax components; transaction total;
* completed tenders, refunds, and cash change;
* distinct original Receipt Numbers for linked return lines;
* `REPRINT` and `VOIDED` notices where applicable.

### 3.2 Gift Receipt *(delivered)*

Non-itemized lookup document: Store header, `GIFT RECEIPT` title, original Receipt Number + barcode, completion timestamp, Store/Register/cashier, `gift_receipt_footer`, `REPRINT`/`VOIDED` when applicable.

Not: itemized receipt, return authorization, bearer credential, separate numbered record, or token.

### 3.3 Post-Void Receipt *(delivered)*

Customer-facing reversing document: `POST-VOID` title, reversing Receipt Number + barcode, original Receipt Number and timestamps, exact reversing lines/discounts/tax/tenders, Store footer, `REPRINT` when historical.

Historical reprint of a Post-Voided original shows `VOIDED`, reversing Receipt Number, and reversal completion timestamp.

### 3.4 Stored-Value Activity Slip *(11.1E)*

Informational slip for one completed Ledger Entry (`issued`, `reloaded`, or `refunded`):

* Store header; activity title; entry timestamp; related Receipt Number when present;
* customer-facing Account Type; masked Account Number only;
* positive activity amount with directional label; historical balance after the Entry;
* `REPRINT` when historical; current informational footer.

Not a bearer credential. Never prints or barcodes the full Account Number.

### 3.5 Credit Voucher *(11.1F)*

Bearer instrument for one active Stored-Value Account:

* Store header; `CREDIT VOUCHER` title; Account Type; current balance and balance-as-of timestamp;
* full canonical Account Number with EAN-13 barcode and human-readable number;
* bearer warning; statement that live ShelfStack balance and status control redemption;
* `REPRINT` when historical (balance reflects print time, not issuance time).

Suspended accounts must not produce an ordinary redeemable Voucher.

---

## 4. Explicitly out of scope

* Cash Movement slips
* Redemption / manual adjustment / reversal Activity Slips; Balance Inquiry Slip
* Session/Business-Day X and Z Reports
* Internal Post-Void audit copy (DWR-017 residual)
* Persisted print-event auditing (INV-POS-014); stored receipt HTML/PDFs
* Gift Receipt records, tokens, or separate numbering
* Receipt-template administration platform; organization-wide document-design settings
* ESC/POS; printer discovery/queues; cross-device orchestration; offline; email/SMS
* Voucher cancellation independent of Account suspension; Alternate Identifier printing

Store edit exposes only the three receipt text fields; fuller settings UI remains [DWR-019](../deferred-work-register.md).

---

## 5. Governing receipt contracts

1. Completed facts remain authoritative — no current pricing/tax/return/inventory recalculation. Current Store presentation config may resolve at render time.
2. Printing remains commercially inert — GET-only; no completion, receipt numbers, tenders, inventory, SV, returns, or post-voids.
3. Price Overrides remain private — print completed selling price only; discounts stay explicit.
4. Customer identity masked on Customer Receipt only; omitted on Gift and Post-Void.
5. Linked return references may be plural.
6. Receipt barcode: Code 128; payload exact `receipt_number`; human-readable beneath; failure leaves document printable.
7. Activity Slip masks Account Numbers; Credit Voucher alone prints and barcodes the full canonical Account Number (EAN-13).
8. Activity Slip balance is historical after the Entry; Credit Voucher balance is current at print time.

---

## 6. Original and reprint authority

Server-owned session-scoped immediate-print context after ordinary or Post-Void completion (and after completions that post in-scope SV Entries). No new database table.

### Receipts

Immediate routes require matching context + `pos.access`; never show `REPRINT`.

Historical `/reprint` routes require `pos.receipt.reprint`; always show `REPRINT` + reprint timestamp. Query params cannot suppress the marker.

```text
GET /pos_transactions/:id/customer_receipt
GET /pos_transactions/:id/customer_receipt/reprint
GET /pos_transactions/:id/gift_receipt
GET /pos_transactions/:id/gift_receipt/reprint
GET /pos_transactions/:id/post_void_receipt
GET /pos_transactions/:id/post_void_receipt/reprint
```

### Stored-Value documents

Immediate routes require matching SV print context + dedicated permission; never show `REPRINT`.

Historical `/reprint` routes require the same dedicated permission; always show `REPRINT`.

```text
GET /stored_value_entries/:id/activity_slip
GET /stored_value_entries/:id/activity_slip/reprint
GET /stored_value_accounts/:id/credit_voucher
GET /stored_value_accounts/:id/credit_voucher/reprint
```

Permissions: `stored_value.activity.print`, `stored_value.voucher.print`.

---

## 7. Entry points

| Context | Actions | Result |
| --- | --- | --- |
| Immediate after ordinary completion | Print Receipt; Print Gift Receipt; Next Transaction | Original |
| Immediate after completion with SV issue/reload/refund | Print Activity Slip; Print Credit Voucher (when eligible) | Original |
| Historical Receipt Lookup | Reprint Receipt; Reprint Gift Receipt; Start Return | REPRINT |
| Historical original after Post-Void | Reprint Receipt; Reprint Gift; View Reversing | REPRINT + VOIDED |
| Immediate after Post-Void | Print Post-Void Receipt; View Original; Next Transaction | Original Post-Void |
| Historical reversing | Reprint Post-Void; View Original | REPRINT |
| Stored-Value Account show | Print Credit Voucher; Reprint Activity Slip per in-scope Entry | REPRINT (historical) / Original (immediate) |

Reversing Post-Void transactions must not offer Gift Receipt.

---

## 8. Data and permissions

* Schema: `stores.gift_receipt_footer` (text) only for receipt docs; no SV print schema columns.
* Receipt permissions: immediate → `pos.access`; historical → `pos.receipt.reprint`. No `pos.gift_receipt.*`.
* SV permissions: `stored_value.activity.print`, `stored_value.voucher.print` (immediate and historical).

---

## 9. Presentation

Browser HTML/CSS targeting ~80 mm thermal; proportional system sans; CSS grid; `font-variant-numeric: tabular-nums`. Dedicated top-level templates with shared partials — not one conditional mega-template.

---

## 10. Delivery gates

| Gate | Outcome | Issue |
| --- | --- | --- |
| **11.1A** | Server print context, shared facts, barcode, shared components | [#152](https://github.com/tswarren/shelfstack-5/issues/152) *(complete)* |
| **11.1B** | Customer hardening + Gift Receipt | [#153](https://github.com/tswarren/shelfstack-5/issues/153) *(complete)* |
| **11.1C** | Post-Void Receipt + VOIDED original reprints | [#154](https://github.com/tswarren/shelfstack-5/issues/154) *(complete)* |
| **11.1D** | Store config, print styling, tests, documentation | [#155](https://github.com/tswarren/shelfstack-5/issues/155) *(complete)* |
| **11.1E** | Stored-Value Activity Slip (issue / reload / refunded) | under epic [#151](https://github.com/tswarren/shelfstack-5/issues/151) |
| **11.1F** | Credit Voucher + permissions/docs exit for SV print reopen | under epic [#151](https://github.com/tswarren/shelfstack-5/issues/151) |

---

## 11. Phase exit

Gates 11.1A–D exit criteria remain satisfied.

Phase 11.1 remains **open** until explicitly closed. When closing is directed, exit requires: Activity Slips for in-scope Entries; Credit Vouchers for active Accounts; dedicated permissions seeded; historical balances on slips and current balances on vouchers; suspended Accounts blocked from Voucher print; browser print only — without new financial records, document identity tables, or printer management.
