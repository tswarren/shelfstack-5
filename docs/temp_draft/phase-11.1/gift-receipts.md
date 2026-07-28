# POS Printing — Gift Receipts

**Status:** Draft
**Scope:** Brief customer-facing Gift Receipts generated from completed POS Transactions
**Parent specification:** [Common Document Contract and Taxonomy](common-document-contract-and-taxonomy.md)
**Related specification:** [Customer Receipts](customer-receipts.md)
**Related domains:** Point of Sale, Returns, Store Configuration

---

## 1. Purpose

A ShelfStack Gift Receipt is a brief, price-suppressed summary that provides enough information to retrieve the original completed POS Transaction.

It follows the BookSense-style operating model defined for ShelfStack:

```text
Gift recipient presents Gift Receipt
→ cashier scans or enters Receipt Number
→ ShelfStack retrieves original completed Transaction
→ ordinary Return workflow determines eligibility and remaining quantity
```

The Gift Receipt is not an itemized customer Receipt and does not independently establish Return entitlement.

It does not create:

* a separate Gift Receipt record;
* a separate Gift Receipt Number;
* line-level Gift Receipt eligibility;
* a secure Return token;
* additional returnable quantity;
* a financial, Inventory, Tax, or Stored-Value posting.

---

## 2. Governing rules

1. A Gift Receipt may be generated only for a completed POS Transaction.

2. The Gift Receipt identifies the original Transaction through its existing Receipt Number.

3. The Receipt Number appears in both barcode and human-readable form.

4. The Gift Receipt contains no merchandise Lines.

5. The Gift Receipt contains no prices, Discounts, Tax, totals, or Tender information.

6. The Gift Receipt contains no Customer identity.

7. The Gift Receipt contains no purchaser payment information.

8. A Gift Receipt does not use a separate token or credential.

9. A Gift Receipt does not create or reserve Return entitlement.

10. Return eligibility and remaining quantity are determined from the retrieved original Transaction and the ordinary Return workflow.

11. Printing a Gift Receipt does not alter the original Transaction.

12. Original versus reprint status is determined by workflow context.

13. A Gift Receipt for a Transaction that has since been Post-Voided must be visibly marked `VOIDED`.

14. Current Store header and Gift Receipt footer configuration may be applied at print time.

15. Printer or rendering failure does not change the completed Transaction.

---

## 3. Source record

The source record is one completed POS Transaction.

```text
Completed POS Transaction
├── Receipt Number
├── completion timestamp
├── Store
├── completed POS Session
├── POS Device / Register
├── cashier
└── Post-Void relationship
```

The Gift Receipt may also use current Store presentation configuration:

```text
Current Store
├── Store and Organization display names
├── address and contact information
├── Receipt header
├── Gift Receipt footer
└── print layout configuration
```

The Gift Receipt does not need to load:

* POS Line Items;
* Discount Allocations;
* Tax Components;
* Tenders;
* Stored-Value Entries;
* Customer;
* Return policies;
* Product or Variant data.

---

## 4. Fact-source matrix

| Printed fact             | Source                                       | Historical or current?                       |
| ------------------------ | -------------------------------------------- | -------------------------------------------- |
| Store name               | Current Store                                | Current presentation                         |
| Organization name        | Current Organization                         | Current presentation                         |
| Store address            | Current Store                                | Current presentation                         |
| Store phone or website   | Current Store                                | Current presentation                         |
| Receipt header           | `stores.receipt_header`                      | Current presentation                         |
| Gift Receipt footer      | `stores.gift_receipt_footer`                 | Current presentation                         |
| Receipt Number           | Completed POS Transaction                    | Historical fact                              |
| Completion date and time | Completed POS Transaction                    | Historical fact                              |
| Store code or number     | Transaction Store                            | Current label for historical Store reference |
| Register                 | Completed POS Session and POS Device         | Current Device label permitted               |
| Cashier                  | Completed Transaction cashier                | Current User display label permitted         |
| Barcode value            | Completed Receipt Number                     | Historical fact                              |
| Original/reprint state   | Trusted workflow context                     | Presentation context                         |
| Post-Void state          | Completed reversing Transaction relationship | Historical correction fact                   |
| Reversing Receipt Number | Completed Post-Void Transaction              | Historical correction fact                   |
| Reprint timestamp        | Current rendering time                       | Presentation context                         |

No Product, Pricing, Tax, Tender, or Return-policy calculation service should be invoked to build a Gift Receipt.

---

## 5. Required content

A Gift Receipt must contain:

1. Store header;
2. `GIFT RECEIPT` title;
3. original or reprint banner, where applicable;
4. `VOIDED` banner, where applicable;
5. Receipt Number;
6. original completion date and time;
7. Store reference where useful for lookup;
8. Register or POS Device reference;
9. cashier label where useful for lookup;
10. Receipt Number barcode;
11. Receipt Number in human-readable form;
12. configured Gift Receipt footer.

Example:

```text
             SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

************ GIFT RECEIPT ************

Receipt MAIN-000184
Jul 27, 2026  3:42 PM
Store MAIN · Register 02
Cashier Jordan

[Code 128 barcode]
MAIN-000184

This Gift Receipt may be used to locate
the original Transaction. Returns remain
subject to Store policy and verification.
```

---

## 6. Prohibited content

A Gift Receipt must not print:

* merchandise descriptions;
* identifiers such as ISBN, UPC, EAN, or SKU;
* quantities;
* unit prices;
* Price Overrides;
* Discounts;
* Tax;
* Transaction subtotal;
* Transaction total;
* Tenders;
* cash tendered;
* change;
* card information;
* Stored-Value Account information;
* Customer Number;
* Customer name;
* purchaser identity;
* Return eligibility;
* Return deadline;
* final-sale status;
* remaining returnable quantity;
* Return history;
* internal Transaction UUID;
* database IDs;
* internal Approval information;
* a separate Gift Receipt Number;
* a Gift Receipt token.

The Gift Receipt is deliberately non-itemized.

---

## 7. Store header

The Gift Receipt uses the common current Store header.

The header may include:

* Store name;
* Organization name;
* Store address;
* phone number;
* website;
* current configured Receipt header;
* logo, where supported.

A later reprint may show updated Store contact information.

ShelfStack does not preserve a historical Store-header snapshot for Gift Receipts.

---

## 8. Transaction lookup identity

### 8.1 Receipt Number

The completed Transaction’s Receipt Number is the authoritative lookup reference.

The Gift Receipt does not receive another number.

Example:

```text
Receipt MAIN-000184
```

### 8.2 Barcode

The barcode encodes the same Receipt Number displayed in human-readable form.

Because ShelfStack Receipt Numbers may contain letters and punctuation, the standard barcode should support alphanumeric values. Code 128 is suitable for the MVP browser-print renderer.

Example:

```text
[Code 128 barcode]
MAIN-000184
```

The barcode must not encode:

* an internal database ID;
* a private UUID;
* Customer identity;
* payment information;
* Return eligibility;
* a separate Gift Receipt token.

### 8.3 Lookup behavior

Scanning or entering the Receipt Number should use ordinary Receipt Lookup.

The lookup process should:

1. search within the current Store by default;
2. retrieve only completed Transactions;
3. identify Post-Voided Transactions;
4. respect Receipt lookup permissions;
5. allow the cashier to begin the ordinary Return workflow where eligible.

The barcode does not bypass Return validation or authorization.

---

## 9. Transaction context

The Gift Receipt should print enough context to assist manual lookup when the barcode cannot be scanned.

Recommended fields:

```text
Receipt MAIN-000184
Jul 27, 2026  3:42 PM
Store MAIN · Register 02
Cashier Jordan
```

### Required

* Receipt Number;
* completion date and time.

### Recommended

* Store code or Store Number;
* Register or POS Device label.

### Optional

* cashier label.

The cashier label may be omitted if the Receipt Number is reliably unique and the additional context does not materially help operations.

Internal POS Session and User IDs do not print.

---

## 10. Gift Receipt footer

Gift Receipts use a dedicated current Store configuration field:

```text
stores.gift_receipt_footer
```

The Gift Receipt footer is separate from the ordinary Customer Receipt footer.

This permits Gift Receipt wording to explain:

* that the document retrieves the original Transaction;
* that Return eligibility is verified at the time of Return;
* that Store policy still applies;
* where to obtain assistance.

Recommended default:

```text
This Gift Receipt may be used to locate
the original Transaction. Returns remain
subject to Store policy and verification.
```

The footer must not promise:

* that every item is returnable;
* a Return deadline not preserved on the completed Transaction;
* a particular refund method;
* a specific Store Credit amount;
* that the Gift Receipt itself proves ownership or eligibility.

---

## 11. Original Gift Receipt

A Gift Receipt is an original when printed from the immediate post-completion Receipt workspace.

Original context includes:

* automatic printing immediately after completion;
* selecting `Print Gift Receipt` from the completed Transaction workspace;
* refreshing that immediate workspace;
* retrying a cancelled or failed browser print;
* printing additional copies before leaving the completion workflow.

Multiple original copies may exist.

Original copies do not display `REPRINT`.

Example:

```text
************ GIFT RECEIPT ************

Receipt MAIN-000184
Jul 27, 2026  3:42 PM
```

---

## 12. Gift Receipt reprint

A Gift Receipt is a reprint when generated after retrieving the completed Transaction through:

* Receipt Lookup;
* Transaction history;
* Customer history;
* reporting;
* audit or administrative access;
* another historical workflow.

A reprinted Gift Receipt must show:

* `REPRINT`;
* original Receipt Number;
* original completion timestamp;
* reprint timestamp.

Example:

```text
************ GIFT RECEIPT ************
**************** REPRINT **************

Receipt MAIN-000184
Originally completed Jul 27, 2026 3:42 PM
Reprinted Jul 28, 2026 10:16 AM
```

The reprint retains the original Receipt Number.

It does not create another Gift Receipt identity or additional Return entitlement.

---

## 13. Gift Receipt for a Post-Voided Transaction

A Gift Receipt must reflect when its source Transaction has since been Post-Voided.

### 13.1 Historical reprint after Post-Void

A reprint must display:

* `GIFT RECEIPT`;
* `REPRINT`;
* `VOIDED`;
* original Receipt Number;
* reversing Receipt Number;
* reversal timestamp.

Example:

```text
************ GIFT RECEIPT ************
**************** REPRINT **************
**************** VOIDED ***************

Receipt MAIN-000184
Originally completed Jul 27, 2026 3:42 PM

Reversed by receipt MAIN-000185
Reversal completed Jul 27, 2026 4:18 PM
```

The barcode may remain present because it retrieves the original Transaction, but the `VOIDED` indication must be prominent.

### 13.2 Printing from the reversing Transaction

The Post-Void Transaction is not itself a valid source for a Gift Receipt.

The `Print Gift Receipt` action should not appear on a completed Post-Void Receipt workspace.

### 13.3 Return behavior

Receipt Lookup should identify the source Transaction as Post-Voided and prevent it from being treated as an active original sale for Return purposes.

The printed `VOIDED` indication is informational. The authoritative control remains the Transaction relationship and Return services.

---

## 14. Cancelled and incomplete Transactions

Gift Receipts are unavailable for:

* open Transactions;
* suspended Transactions;
* cancelled Transactions;
* failed completion attempts.

Only a successfully completed Transaction with an assigned Receipt Number can produce a Gift Receipt.

Attempting to request a Gift Receipt for an ineligible Transaction must:

* display a visible error;
* leave the Transaction unchanged;
* consume no Receipt Number;
* create no new record.

---

## 15. Permissions

### 15.1 Immediate original

Printing an original Gift Receipt from the immediate completed-Transaction workspace should require:

* ordinary POS access to the completed Transaction.

It should not require historical Receipt-reprint permission merely because the User chooses another print format from the same completion workflow.

### 15.2 Historical reprint

Printing a Gift Receipt after historical retrieval should require:

* Receipt lookup access; and
* the canonical Receipt-reprint permission.

A separate Gift Receipt reprint permission is not necessary for MVP because the document contains less information than the ordinary Customer Receipt.

### 15.3 Source visibility

A User may not print a Gift Receipt for a Transaction they are not authorized to retrieve.

---

## 16. Workflow entry points

### 16.1 Immediate completion workspace

The completed Transaction workspace should offer:

```text
Print Receipt
Print Gift Receipt
Next Transaction
```

`Print Gift Receipt` produces an original Gift Receipt while the server-owned immediate completion context remains valid.

### 16.2 Historical Receipt Lookup

Historical Transaction actions may offer:

```text
Reprint Receipt
Reprint Gift Receipt
Start Return
```

`Reprint Gift Receipt` always produces a document marked `REPRINT`.

### 16.3 Post-Void restrictions

For a Post-Voided original:

```text
Reprint Receipt
Reprint Gift Receipt
View Reversing Receipt
```

Both historical documents display `VOIDED`.

For the reversing Post-Void Transaction:

```text
Reprint Post-Void Receipt
View Original Receipt
```

No Gift Receipt action appears.

---

## 17. Server-owned print context

Original versus reprint status must not be controlled solely by a query parameter.

Recommended route separation:

```text
GET /pos_transactions/:id/gift_receipt
  immediate original context only

GET /pos_transactions/:id/gift_receipt/reprint
  historical reprint context
```

The immediate route should confirm that:

* the Transaction is completed;
* the current User has access to the Transaction;
* the Transaction matches the server-owned immediate completion context.

The historical route should:

* require Receipt-reprint permission;
* always render `REPRINT`;
* ignore attempts to suppress the marker.

An equivalent trusted server design is acceptable.

---

## 18. Structured document contract

Recommended builder:

```text
PosPrinting::BuildGiftReceipt
```

Input:

```text
completed_pos_transaction
document_context: original | reprint
```

Output:

```text
PosPrinting::Document
```

The builder owns:

* completed-source validation;
* Receipt Number;
* completion timestamp;
* original/reprint status;
* Post-Void status;
* reversing Receipt reference;
* Store and Register context;
* barcode value;
* current Gift Receipt footer;
* safe omission of prohibited facts.

The builder should not load POS Lines, Discounts, Tax Components, or Tenders.

---

## 19. Rendering contract

The browser-print renderer owns:

* Store-header layout;
* document banners;
* metadata alignment;
* barcode generation;
* human-readable Receipt Number;
* footer wrapping;
* 80 mm print styling;
* page-break behavior;
* hiding browser controls in print output.

The standard thermal profile should target 80 mm paper.

A Gift Receipt should normally fit on a short single sheet.

No empty item, totals, Tax, or Tender sections should be rendered.

---

## 20. Error handling

Gift Receipt generation or rendering failure must:

* leave the completed Transaction unchanged;
* display an actionable error;
* permit retry;
* create no new Transaction;
* consume no Receipt Number;
* post no Tender;
* create no Stored-Value Entry;
* create no Gift Receipt record.

Presentation failures should degrade gracefully.

Examples:

* missing Store phone → omit phone;
* missing Register name → use stable Device code;
* missing Gift Receipt footer → use fixed default wording;
* barcode rendering unavailable → show the human-readable Receipt Number prominently and report the barcode error without modifying the source Transaction.

The document should not fail merely because optional Store presentation fields are missing.

---

## 21. Data and schema requirements

### 21.1 Required schema addition

```ruby
add_column :stores, :gift_receipt_footer, :text
```

### 21.2 No additional Gift Receipt schema

Do not add:

```text
gift_receipts
gift_receipt_lines
gift_receipt_number
gift_receipt_token
gift_receipt_token_digest
gift_receipt_status
gift_receipt_expires_at
gift_receipt_print_events
```

The completed Transaction remains the sole source identity.

### 21.3 No Receipt changes required

The following existing facts are sufficient:

* Receipt Number;
* completed timestamp;
* Store;
* completed POS Session;
* cashier;
* Post-Void relationship.

---

## 22. MVP acceptance scenarios

### 22.1 Original Gift Receipt

Given a completed ordinary Transaction and valid immediate completion context:

* `GIFT RECEIPT` appears;
* `REPRINT` does not appear;
* Receipt Number prints;
* completion timestamp prints;
* barcode encodes the Receipt Number;
* human-readable Receipt Number appears;
* current Gift Receipt footer appears.

### 22.2 No itemization

Given a Transaction with multiple merchandise Lines:

* no item descriptions print;
* no identifiers print;
* no quantities print;
* no prices print.

### 22.3 No financial information

The Gift Receipt contains no:

* subtotal;
* Discount;
* Tax;
* total;
* Tender;
* change;
* Stored-Value amount.

### 22.4 No Customer information

Given an attached Customer:

* Customer Number does not print;
* Customer name does not print;
* Customer contact information does not print.

### 22.5 Historical reprint

Given a completed Transaction retrieved through Receipt Lookup:

* `REPRINT` appears;
* the original Receipt Number remains;
* original completion timestamp appears;
* reprint timestamp appears;
* no new business record is created.

### 22.6 Caller cannot suppress reprint status

Given the historical reprint route:

* supplying `reprint=false` or an equivalent parameter does not remove `REPRINT`.

### 22.7 Post-Voided original

Given an original Transaction that has a completed Post-Void:

* `VOIDED` appears;
* reversing Receipt Number appears;
* reversal timestamp appears;
* Receipt barcode still identifies the original Transaction;
* the Return workflow rejects the Transaction as an active original sale.

### 22.8 Post-Void source restriction

Given a completed Post-Void Transaction:

* Gift Receipt printing is unavailable;
* directly requesting a Gift Receipt returns a visible error or redirects safely.

### 22.9 Incomplete Transaction

Given an open, suspended, or cancelled Transaction:

* Gift Receipt generation is denied;
* no document is produced;
* no source record changes.

### 22.10 Current configuration

Given a changed Store header or Gift Receipt footer:

* a later Gift Receipt uses the current values;
* the Receipt Number and completion time remain historical.

### 22.11 Missing footer

Given no configured Gift Receipt footer:

* fixed fallback wording prints;
* the Gift Receipt remains usable.

### 22.12 Barcode failure

Given a barcode-rendering failure:

* the human-readable Receipt Number remains visible;
* no Transaction mutation occurs;
* retry remains possible.

---

## 23. MVP boundaries

### Required

* completed Transactions only;
* brief, non-itemized Gift Receipt;
* Store header;
* Receipt Number;
* completion date and time;
* Store/Register context;
* optional cashier context;
* Code 128 Receipt barcode;
* human-readable Receipt Number;
* dedicated Gift Receipt footer;
* original/reprint workflow context;
* `VOIDED` indication for Post-Voided originals;
* browser-printable HTML;
* 80 mm print styling;
* no Gift Receipt persistence.

### Deferred

* direct ESC/POS output;
* email or SMS delivery;
* QR code;
* cross-Store Gift Receipt lookup policy;
* configurable Gift Receipt field ordering;
* multiple Gift Receipt footer templates;
* multilingual Gift Receipt templates;
* browser print-event audit;
* physical print-success detection;
* Gift Receipt-specific permission;
* separate online Return portal.

---

## 24. Remaining decisions

### 24.1 Cashier label

Decide whether the standard Gift Receipt always prints the cashier label or only Store, Register, Receipt Number, and completion time.

**Recommended MVP:** print the cashier label because it may assist manual Transaction retrieval and issue investigation.

### 24.2 Cross-Store lookup

Decide whether a Gift Receipt from one Store may be retrieved or returned at another Store in the same Organization.

This is a Return and Store-policy decision, not a barcode or Gift Receipt data-model decision.

The Receipt Number and Store reference should be sufficient to support a later cross-Store policy.

### 24.3 Barcode fallback behavior

Decide whether a barcode-generation failure:

* renders the document without a barcode but with a prominent Receipt Number; or
* blocks printing until barcode rendering succeeds.

**Recommended MVP:** allow printing with the human-readable Receipt Number and display a warning. The barcode improves speed but is not the authoritative identity.
