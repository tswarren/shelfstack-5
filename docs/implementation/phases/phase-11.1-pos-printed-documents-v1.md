# Phase 11.1 — POS printed documents v1

**Status:** Fully complete — epic [#151](https://github.com/tswarren/shelfstack-5/issues/151); gates [#152](https://github.com/tswarren/shelfstack-5/issues/152)–[#155](https://github.com/tswarren/shelfstack-5/issues/155)
**Depends on:** Phase 11 closed; Phase 6 post-void and corrections; Phase 9 Customer v1
**Primary register item:** [DWR-017](../deferred-work-register.md), partially
**Source design packet:** [00_pos_printing-simplified.md](../../temp_draft/phase-11.1/00_pos_printing-simplified.md) (primary build contract); [typography.md](../../temp_draft/phase-11.1/typography.md); longer drafts under [phase-11.1/](../../temp_draft/phase-11.1/) are background
**Governing docs:** [Phase 11 — POS Shell and Workspace Revamp](phase-11-pos-shell-and-workspace-revamp.md); [Point of Sale](../../domains/point-of-sale.md); [Authorization and Permissions](../../domains/authorization-permissions.md); ADR-0008; ADR-0009
**Epic:** [#151](https://github.com/tswarren/shelfstack-5/issues/151)
**Gate issues:** [#152](https://github.com/tswarren/shelfstack-5/issues/152) (11.1A), [#153](https://github.com/tswarren/shelfstack-5/issues/153) (11.1B), [#154](https://github.com/tswarren/shelfstack-5/issues/154) (11.1C), [#155](https://github.com/tswarren/shelfstack-5/issues/155) (11.1D)

---

## 1. Characterization

Phase 11.1 is a focused follow-on to Phase 11 Gate D.

Phase 11 established the completed-transaction Receipt presentation, browser-printable customer receipts, historical receipt lookup, receipt reprinting, completed-fact rendering, and basic return/mixed/post-void banners.

Phase 11.1 turns that minimum into the MVP receipt product with three browser-printable documents:

1. Customer Receipt
2. Gift Receipt
3. Post-Void Receipt

This phase is not a general document-generation framework.

---

## 2. Goal

Deliver reliable, privacy-conscious, browser-printable receipts that:

* reproduce completed POS facts without recalculation;
* clearly distinguish originals, reprints, and voided activity;
* support fast transaction lookup through a receipt-number barcode;
* provide a narrowly defined non-itemized Gift Receipt;
* provide customer-facing evidence of a completed Post-Void;
* remain independent of transaction completion and other posting operations.

A print, render, barcode, or browser failure after successful transaction completion must never reopen, reverse, or invalidate the completed transaction.

---

## 3. MVP scope

### 3.1 Customer Receipt

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

### 3.2 Gift Receipt

Non-itemized lookup document: Store header, `GIFT RECEIPT` title, original Receipt Number + barcode, completion timestamp, Store/Register/cashier, `gift_receipt_footer`, `REPRINT`/`VOIDED` when applicable.

Not: itemized receipt, return authorization, bearer credential, separate numbered record, or token.

### 3.3 Post-Void Receipt

Customer-facing reversing document: `POST-VOID` title, reversing Receipt Number + barcode, original Receipt Number and timestamps, exact reversing lines/discounts/tax/tenders, Store footer, `REPRINT` when historical.

Historical reprint of a Post-Voided original shows `VOIDED`, reversing Receipt Number, and reversal completion timestamp.

---

## 4. Explicitly out of scope

* Cash Movement slips; stored-value Activity Slips; store-credit/trade-credit vouchers
* Session/Business-Day X and Z Reports
* Internal Post-Void audit copy (DWR-017 residual)
* Persisted print-event auditing (INV-POS-014); stored receipt HTML/PDFs
* Gift Receipt records, tokens, or separate numbering
* Receipt-template administration platform; organization-wide document-design settings
* ESC/POS; printer discovery/queues; cross-device orchestration; offline; email/SMS

Store edit exposes only the three receipt text fields; fuller settings UI remains [DWR-019](../deferred-work-register.md).

---

## 5. Governing receipt contracts

1. Completed facts remain authoritative — no current pricing/tax/return/inventory recalculation. Current Store presentation config may resolve at render time.
2. Printing remains commercially inert — GET-only; no completion, receipt numbers, tenders, inventory, SV, returns, or post-voids.
3. Price Overrides remain private — print completed selling price only; discounts stay explicit.
4. Customer identity masked on Customer Receipt only; omitted on Gift and Post-Void.
5. Linked return references may be plural.
6. Barcode: Code 128; payload exact `receipt_number`; human-readable beneath; failure leaves document printable.

---

## 6. Original and reprint authority

Server-owned session-scoped immediate-print context after ordinary or Post-Void completion. No new database table.

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

---

## 7. Entry points

| Context | Actions | Result |
| --- | --- | --- |
| Immediate after ordinary completion | Print Receipt; Print Gift Receipt; Next Transaction | Original |
| Historical Receipt Lookup | Reprint Receipt; Reprint Gift Receipt; Start Return | REPRINT |
| Historical original after Post-Void | Reprint Receipt; Reprint Gift; View Reversing | REPRINT + VOIDED |
| Immediate after Post-Void | Print Post-Void Receipt; View Original; Next Transaction | Original Post-Void |
| Historical reversing | Reprint Post-Void; View Original | REPRINT |

Reversing Post-Void transactions must not offer Gift Receipt.

---

## 8. Data and permissions

* Schema: `stores.gift_receipt_footer` (text) only.
* Permissions: immediate → `pos.access`; historical → `pos.receipt.reprint`. No `pos.gift_receipt.*`.

---

## 9. Presentation

Browser HTML/CSS targeting ~80 mm thermal; proportional system sans; CSS grid; `font-variant-numeric: tabular-nums`. Dedicated top-level templates with shared partials — not one conditional mega-template.

---

## 10. Delivery gates

| Gate | Outcome | Issue |
| --- | --- | --- |
| **11.1A** | Server print context, shared facts, barcode, shared components | [#152](https://github.com/tswarren/shelfstack-5/issues/152) |
| **11.1B** | Customer hardening + Gift Receipt | [#153](https://github.com/tswarren/shelfstack-5/issues/153) |
| **11.1C** | Post-Void Receipt + VOIDED original reprints | [#154](https://github.com/tswarren/shelfstack-5/issues/154) |
| **11.1D** | Store config, print styling, tests, documentation | [#155](https://github.com/tswarren/shelfstack-5/issues/155) |

---

## 11. Phase exit

Phase 11.1 is complete when ordinary completed transactions produce Customer and Gift Receipts; Post-Void transactions produce Post-Void Receipts; Post-Voided originals produce VOIDED Customer/Gift reprints — using completed historical facts, current Store presentation config, server-owned original/reprint context, existing permissions, and browser print — without new financial records, document identity, or printer management.
